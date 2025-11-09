# Feel-IT: A Smart Haptic Feedback System

Feel-IT is a smart, wearable haptic feedback system designed for the deaf and hard-of-hearing. It uses an iPhone's on-device machine learning to listen to the environment, intelligently filters for sounds the user cares about, and sends clear, labeled alerts to a custom-built ESP32 wearable.

This project was built for a hackathon at the University at Buffalo.

---

## 🧠 Features

- **Intelligent Sound Classification:** Uses Apple’s `SoundAnalysis` framework to detect 100+ different sounds in real-time.  
- **User Customization:** The app features a settings page where users can select up to 20 sounds they want to be notified about (e.g., “Baby Crying,” “Fire Alarm,” “Doorbell”).  
- **Alert Fatigue Prevention:** All unselected sounds are intelligently ignored, so the user is only alerted to what they have defined as important.  
- **Dynamic Visuals:** The ESP32 wearable displays the human-readable name of the sound (e.g., “DOG BARK”) and a confidence bar.  
- **Professional Haptics:** Uses a `DRV2605L` haptic driver to play a crisp, distinct “Triple Click” effect for each alert.  
- **App-Controlled State:** The wearable has “Ready” and “Listening” states, controlled remotely by the iPhone app to save power and provide clear status.  

---

## ⚙️ How It Works: System Architecture

The project follows a **client-server model** with two main components:  
- The **iOS app** (the "Brain")  
- The **ESP32 wearable** (the "Feeler")  

---

### 📱 iOS Application (The “Brain”)

The iPhone handles all the heavy lifting: listening, analysis, and filtering.

#### Key Files

- **`YourAppNameApp.swift`** – The main SwiftUI entry point. Initializes the `SoundStore` and presents the `HomeView`.  
- **`HomeView.swift`** – The main navigation screen (SwiftUI) with two buttons:  
  - “Start Listening” → Navigates to the `ListeningViewWrapper`.  
  - “Add/Edit Sounds” → Navigates to the `SoundSelectionView`.  
- **`SoundStore.swift`** – The “single source of truth” for user preferences.  
  - Holds `allSounds` master list.  
  - Manages `selectedSoundIDs` set.  
  - Saves and loads preferences via `UserDefaults`.  
- **`SoundSelectionView.swift`** – The SwiftUI settings screen for selecting up to 20 sounds.  
- **`ListeningViewWrapper.swift`** – A SwiftUI-to-UIKit bridge to display the `ViewController`.  
- **`ViewController.swift`** – The main “Listening” screen (UIKit).  
  - In `viewDidAppear`: sends `CMD:START_LISTENING`.  
  - In `viewWillDisappear`: sends `CMD:STOP_LISTENING`.  
- **`SoundBridge.swift`** – Core ML logic and sound routing.  
  - Uses `AVAudioEngine` and `SNAudioStreamAnalyzer` for sound classification.  
  - `norm()` groups similar sounds (e.g., “applause,” “finger_snapping”) into one ID.  
  - Checks `SoundStore.shared.isSoundSelected()` before processing.  
  - Sends formatted string (e.g., `"Clapping:85"`) to BLE.  
- **`BLEClient.swift`** – Manages all CoreBluetooth tasks.  
  - Scans for `HapNode-01` device.  
  - Connects and provides a simple `send(data: String)` API.  

---

### ⚡ ESP32 Wearable (The “Feeler”)

The wearable acts as a BLE server, displaying alerts and providing haptic feedback.

#### Key File

- **`Feel-IT_ESP32_DRV2605.ino`** – Main firmware for the ESP32.

#### Libraries Used

- `BLEDevice` – BLE server and GATT communication.  
- `TFT_eSPI` – For drawing text and UI elements on the screen.  
- `Adafruit_DRV2605` – For haptic motor control.

#### Core Logic

- Maintains a boolean `isListening` (default `false`).  
- **`showHome()`** displays “Hi there, I’m Ready.”  
- **`showListening()`** displays “Feel-IT, Listening….”  

##### BLE `onWrite()` Callback
- Checks if message is a command (`CMD:START_LISTENING` or `CMD:STOP_LISTENING`).  
- If not a command and `!isListening`, ignores the sound.  
- Parses `"Label:Confidence"` format (e.g., `"Clapping:85"`).  
- Calls `showEventOnScreen()` to update the TFT display with color-coded confidence.  
- Triggers `playHapticAlert()` to activate DRV2605 “Triple Click.”  

---

## 🔩 Hardware Requirements

| Component | Description |
|------------|-------------|
| **ESP32 Board** | LILYGO T-Display or similar ESP32 with TFT screen |
| **Haptic Driver** | DRV2605L breakout board |
| **Vibration Motor** | 10mm ERM coin vibration motor |
| **iPhone** | iOS 15+ for SoundAnalysis support |

---

## 🧰 Software Setup

### 📲 iOS App (Xcode)

1. Open the Xcode project (`.xcodeproj` or `.xcworkspace`).  
2. Select your iPhone as the build target.  
3. Assign your developer account in **Signing & Capabilities**.  
4. Press **Run** to build and deploy.

### 🔧 ESP32 Wearable (Arduino IDE)

1. Open `Feel-IT_ESP32_DRV2605.ino` in Arduino IDE.  
2. Go to **Tools → Manage Libraries…** and install:  
   - `TFT_eSPI` (by Bodmer)  
   - `Adafruit DRV2605` (by Adafruit)  
3. Go to **Tools → Board** and select your ESP32 board (e.g., “TTGO T-Display”).  
4. Connect via USB, select the correct COM port, and click **Upload**.

---

## 🏗️ System Diagram

```markdown
![System Architecture](images/system_workflow.png)
```

*(Add your Figma or architecture image in the `/images` folder and update the path above.)*

---

## 📜 License

This project is released under the **MIT License**.

