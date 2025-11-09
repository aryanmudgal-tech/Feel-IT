import Foundation
import CoreBluetooth

// --- FIX: These two lines were missing ---
let SERVICE_UUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
let TX_UUID      = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
// ----------------------------------------

final class BLEClient: NSObject {
    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var txChar: CBCharacteristic?

    var onStatus: ((String, Bool) -> Void)?
    var isConnected: Bool { txChar != nil }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // --- Public send API ---
    func send(data: String) {
        guard let p = peripheral, let c = txChar else {
            print("BLE: Not ready to send. No peripheral or characteristic.")
            return
        }
        
        guard let dataToSend = data.data(using: .utf8) else {
            print("BLE: Failed to encode string to UTF-8")
            return
        }

        let writeType: CBCharacteristicWriteType = c.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        
        p.writeValue(dataToSend, for: c, type: writeType)
        // print("BLE: Wrote \(dataToSend.count) bytes for string: \(data)")
    }
}

// MARK: - CBCentralManagerDelegate
extension BLEClient: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            onStatus?("Bluetooth OFF", false)
            return
        }
        onStatus?("Scanning...", false)
        central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi RSSI: NSNumber) {
        
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? peripheral.name ?? "Unknown"
        
        if name.hasPrefix("HapNode") {
            self.peripheral = peripheral
            onStatus?("Connecting to \(name)...", false)
            central.stopScan()
            central.connect(peripheral, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        onStatus?("Discovering services...", true)
        peripheral.delegate = self
        peripheral.discoverServices([SERVICE_UUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        onStatus?("Connection failed", false)
        self.peripheral = nil
        central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        txChar = nil
        self.peripheral = nil
        onStatus?("Disconnected. Re-scanning...", false)
        central.scanForPeripherals(withServices: [SERVICE_UUID], options: nil)
    }
}

// MARK: - CBPeripheralDelegate
extension BLEClient: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let svc = peripheral.services?.first(where: { $0.uuid == SERVICE_UUID }) else {
            onStatus?("Service not found", false)
            return
        }
        onStatus?("Discovering characteristics...", true)
        peripheral.discoverCharacteristics([TX_UUID], for: svc)
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        txChar = service.characteristics?.first(where: { $0.uuid == TX_UUID })
        
        if txChar != nil {
            onStatus?("Connected to HapNode-01", true)
        } else {
            onStatus?("Write characteristic not found", false)
        }
    }
}
