import Foundation
import CoreBluetooth
import Combine

func parseHeartRateMeasurement(data: Data) -> String? {
    guard data.count > 0 else { return nil }
    
    // First byte is the Flags
    let flags = data[0]
    let is16BitHeartRate = (flags & 0x01) != 0
    
    // Heart Rate Value
    let heartRate: Int
    if is16BitHeartRate {
        // If the heart rate is 16-bit, ensure there are at least 3 bytes
        guard data.count >= 3 else { return nil }
        heartRate = Int(data[1]) | (Int(data[2]) << 8)
    } else {
        // If the heart rate is 8-bit, read the second byte
        guard data.count >= 2 else { return nil }
        heartRate = Int(data[1])
    }
    
    return "Heart Rate: \(heartRate) bpm"
}

func parseBatteryLevel(data: Data) -> String? {
    guard let batteryLevel = data.first else { return nil }
    return "\(batteryLevel)%"
}

func parseSensorContactStatus(data: Data) -> String? {
    guard let contactStatus = data.first else { return nil }
    return contactStatus == 0x00 ? "No Contact" : "Contact Detected"
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var devices: [BLEDevice] = []
    @Published var connectedDevice: BLEDevice? = nil
    @Published var deviceProperties: [String: String] = [:] // Properties of the connected device
        
    public var centralManager: CBCentralManager!
    private var activePeripheral: CBPeripheral? = nil
    
    
    // List of sport-related service UUIDs
    private let sportServiceUUIDs: [CBUUID] = [
        CBUUID(string: "180D"), // Heart Rate Service
        CBUUID(string: "1816"), // Cycling Speed and Cadence
        CBUUID(string: "1818")  // Cycling Power Service
    ]
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    
    // MARK: - Bluetooth State Management
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: sportServiceUUIDs, options: nil)
        }
    }
    
    // MARK: - Device Discovery
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let deviceName = peripheral.name ?? "Unknown Device"
        let deviceID = peripheral.identifier

        if !devices.contains(where: { $0.id == deviceID }) {
            print("Adding \(deviceID) to the list of devices.")
            let newDevice = BLEDevice(id: deviceID, name: deviceName, rssi: RSSI.intValue, peripheral: peripheral)
            self.devices.append(newDevice)
        }
    }
    
    // MARK: - Connect to a Device
    func connect(to device: BLEDevice) {
        guard let peripheral = device.peripheral else { return }
        activePeripheral = peripheral
        connectedDevice = device
        centralManager.connect(peripheral, options: nil)
        peripheral.delegate = self

    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        peripheral.discoverServices(nil) // Discover all services
    }
    
    // MARK: - Discover Services and Characteristics
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        peripheral.services?.forEach { service in
            print("Discovered service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        service.characteristics?.forEach { characteristic in
                print("Discovered characteristic: \(characteristic.uuid) with properties: \(characteristic.properties)")
                
                // Check if the characteristic is readable
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                } else if characteristic.properties.contains(.notify) {
                    // Enable notifications if supported
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value: \(error!.localizedDescription)")
            return
        }
        
        if let value = characteristic.value {
            if characteristic.uuid == CBUUID(string: "2A37") {
                // Parse Heart Rate Measurement
                let heartRate = parseHeartRateMeasurement(data: value)
                DispatchQueue.main.async {
                    self.deviceProperties["Heart Rate"] = heartRate
                }
            } else if characteristic.uuid == CBUUID(string: "2A19") {
                // Parse Battery Level
                let batteryLevel = parseBatteryLevel(data: value)
                DispatchQueue.main.async {
                    self.deviceProperties["Battery Level"] = batteryLevel
                }
            } else if characteristic.uuid == CBUUID(string: "2A5B") {
                // Parse Sensor Contact Status
                let contactStatus = parseSensorContactStatus(data: value)
                DispatchQueue.main.async {
                    self.deviceProperties["Sensor Contact Status"] = contactStatus
                }
            }
        }
    }
}



/// Represents a BLE device discovered during scanning.
struct BLEDevice: Identifiable {
    let id: UUID        // Unique identifier for the peripheral
    let name: String    // Device name
    let rssi: Int       // Signal strength
    let peripheral: CBPeripheral?
}
