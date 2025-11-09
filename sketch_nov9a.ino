// ===== Feel-IT / HapNode-01 (ESP32 T-Display) =====
// BLE -> "label:NN"  shows on TFT and vibrates
// DRV2605 (I2C) if present, else fallback GPIO motor

#include <Arduino.h>

// ---------- BLE ----------
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ---------- Display ----------
#include <TFT_eSPI.h>
#include <SPI.h>

// ---------- Haptics ----------
#include <Wire.h>
#include "Adafruit_DRV2605.h"

// ====== CONFIG ======
static BLEUUID SERVICE_UUID("6E400001-B5A3-F393-E0A9-E50E24DCCA9E");
static BLEUUID RX_CHAR_UUID("6E400002-B5A3-F393-E0A9-E50E24DCCA9E"); // iPhone writes here

// DRV2605 on default I2C addr 0x5A. T-Display ESP32: SDA=21, SCL=22.
constexpr int I2C_SDA = 21;
constexpr int I2C_SCL = 22;

// Optional discrete motor fallback (via MOSFET/transistor).
// Set to -1 if you don't have one. Example pin: 14.
constexpr int PIN_MOTOR_FALLBACK = -1;

// TFT backlight pin on many T-Display boards:
constexpr int PIN_TFT_BL = 4;

// ====== GLOBALS ======
TFT_eSPI tft;
Adafruit_DRV2605 drv;
bool drv_ok = false;

unsigned long lastEventMillis = 0;
const unsigned long EVENT_HOLD_MS = 5000;
unsigned long lastHomeDraw = 0;

// ====== UTIL ======
static void tftInitOnce() {
  tft.init();
  tft.setRotation(1);
  if (PIN_TFT_BL >= 0) {
    pinMode(PIN_TFT_BL, OUTPUT);
    digitalWrite(PIN_TFT_BL, HIGH);
  }
  tft.fillScreen(TFT_BLACK);
  tft.setTextDatum(MC_DATUM);
}

static void drawCentered(const String &line1, const String &line2, uint16_t color = TFT_WHITE) {
  tft.fillScreen(TFT_BLACK);
  tft.setTextColor(color, TFT_BLACK);
  tft.setTextFont(2);
  tft.drawString(line1, tft.width()/2, tft.height()/2 - 18, 2);
  tft.setTextFont(4);
  String upper = line2; upper.toUpperCase();
  tft.drawString(upper, tft.width()/2, tft.height()/2 + 12, 4);
}

static void showStatus(const char *s) { drawCentered("Status", s, TFT_GREEN); }
static void showHome() { drawCentered("Hi there!", "Let's Feel it", TFT_WHITE); }

static uint16_t scaleColor(uint16_t color, uint8_t brightness) {
  float f = brightness / 100.0f;
  if (f < 0.5f) f = 0.5f;
  if (f > 1.0f) f = 1.0f;
  uint8_t r = (color >> 11) & 0x1F, g = (color >> 5) & 0x3F, b = color & 0x1F;
  r = (uint8_t)(r * f); g = (uint8_t)(g * f); b = (uint8_t)(b * f);
  return (r << 11) | (g << 5) | b;
}

static uint16_t colorFor(const String &label) {
  unsigned long hash = 0;
  for (int i = 0; i < label.length(); i++) hash = (hash * 31U + (uint8_t)label[i]) % 360U;
  float hue = (float)hash / 360.0f;
  float r,g,b; int k = (int)floor(hue*6.0f); float f = hue*6.0f - k; float q = 1.0f - f;
  switch (k % 6) {
    case 0: r=1,g=f,b=0; break; case 1: r=q,g=1,b=0; break;
    case 2: r=0,g=1,b=f; break; case 3: r=0,g=q,b=1; break;
    case 4: r=f,g=0,b=1; break; default: r=1,g=0,b=q; break;
  }
  return ((uint8_t)(r*31)<<11)|((uint8_t)(g*63)<<5)|((uint8_t)(b*31));
}

static void showEventOnScreen(const String &label, uint8_t conf) {
  uint16_t col = scaleColor(colorFor(label), conf);
  char buf[64]; snprintf(buf, sizeof(buf), "%s (%u%%)", label.c_str(), conf);
  drawCentered("Detected", buf, col);

  // confidence bar
  int barY = tft.height() - 20, barH = 10, maxW = tft.width() - 40;
  float cs = (conf - 50.0f) / 50.0f; if (cs < 0) cs = 0; if (cs > 1) cs = 1;
  int w = (int)(maxW * cs), x = (tft.width() - maxW)/2;
  tft.drawRect(x, barY, maxW, barH, TFT_WHITE);
  tft.fillRect(x+1, barY+1, w, barH-2, col);

  lastEventMillis = millis();
}

// ====== HAPTICS ======
static void buzzFallback(uint16_t onMs, uint16_t offMs, uint8_t reps) {
  if (PIN_MOTOR_FALLBACK < 0) return;
  for (uint8_t i = 0; i < reps; i++) {
    digitalWrite(PIN_MOTOR_FALLBACK, HIGH); delay(onMs);
    digitalWrite(PIN_MOTOR_FALLBACK, LOW);
    if (i + 1 < reps) delay(offMs);
  }
}

// Choose a DRV2605 effect set based on confidence
static void playDRV(uint8_t conf) {
  // Some nice presets:
  //  12 = Triple Click;  1 = Strong Click (100%);  47 = Transition Click;  14 = Double Sharp Click
  uint8_t e0, e1 = 0;
  if (conf < 75)       e0 = 1;      // single strong
  else if (conf < 95)  e0 = 14;     // double
  else                 e0 = 12;     // triple

  drv.setWaveform(0, e0);
  drv.setWaveform(1, 0); // end
  drv.go();
}

static void hapticFor(uint8_t conf) {
  if (drv_ok) playDRV(conf);
  else buzzFallback(conf < 75 ? 80 : (conf < 95 ? 100 : 120),
                    conf < 75 ? 0  : (conf < 95 ? 60  : 80),
                    conf < 75 ? 1  : (conf < 95 ? 2   : 3));
}

// ====== BLE ======
class RxCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *ch) override {
    String s = String(ch->getValue().c_str());
    s.trim();
    if (!s.length()) return;

    Serial.printf("RX: \"%s\"\n", s.c_str());

    // Accept either "label:NN" or just "label"
    String label; uint8_t conf = 100;
    int colon = s.lastIndexOf(':');
    if (colon != -1) { label = s.substring(0, colon); conf = s.substring(colon+1).toInt(); }
    else label = s;

    Serial.printf("Event → %s (%u%%)\n", label.c_str(), conf);
    showEventOnScreen(label, conf);
    hapticFor(conf);
  }
};

class ServerCB : public BLEServerCallbacks {
  void onConnect(BLEServer *s) override { Serial.println("BLE connected"); showStatus("BLE connected"); }
  void onDisconnect(BLEServer *s) override {
    Serial.println("BLE disconnected");
    showStatus("BLE disconnected");
    s->startAdvertising();
  }
};

void setup() {
  Serial.begin(115200);
  delay(150);

  // Fallback motor pin
  if (PIN_MOTOR_FALLBACK >= 0) {
    pinMode(PIN_MOTOR_FALLBACK, OUTPUT);
    digitalWrite(PIN_MOTOR_FALLBACK, LOW);
  }

  // Display
  tftInitOnce();
  showStatus("Booting…");

  // I2C + DRV2605 (non-blocking init)
  Serial.println("Init DRV2605…");
  Wire.begin(I2C_SDA, I2C_SCL);
  drv_ok = drv.begin();
  if (drv_ok) {
    Serial.println("DRV2605 OK");
    drv.useERM();                 // ERM motor
    drv.selectLibrary(1);         // Library 1 is a good default
    drv.setMode(DRV2605_MODE_INTTRIG);
  } else {
    Serial.println("DRV2605 NOT FOUND — using GPIO fallback (if configured).");
  }

  // BLE
  BLEDevice::init("HapNode-01");
  BLEServer *srv = BLEDevice::createServer();
  srv->setCallbacks(new ServerCB());

  BLEService *svc = srv->createService(SERVICE_UUID);

  BLECharacteristic *rx = svc->createCharacteristic(
    RX_CHAR_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  rx->setCallbacks(new RxCallbacks());

  svc->start();

  BLEAdvertising *adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(SERVICE_UUID);
  adv->setScanResponse(true);
  adv->setMinPreferred(0x06);
  adv->setMaxPreferred(0x12);
  adv->start();

  Serial.println("Advertising as HapNode-01");
  showStatus("Advertising…");
  showHome();
}

void loop() {
  // revert to home after a while
  if (millis() - lastEventMillis > EVENT_HOLD_MS) {
    if (millis() - lastHomeDraw > 2000) {
      lastHomeDraw = millis();
      showHome();
    }
  }
}
