import BLECore
import CoreBluetooth
import Foundation

struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var hasEnvironmentalService: Bool
    var lastSeen: Date
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time: Date
    let text: String
}

enum LinkState: Equatable {
    case idle
    case connecting
    case connected
    case reconnecting
    case failed(String)

    var label: String {
        switch self {
        case .idle: return "Not connected"
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .reconnecting: return "Link lost, reconnecting..."
        case .failed(let reason): return "Failed: \(reason)"
        }
    }
}

/// Owns the CoreBluetooth central. All callbacks arrive on the main queue,
/// so published properties are always updated on the main thread.
final class BLEManager: NSObject, ObservableObject {
    @Published var bluetoothState: CBManagerState = .unknown
    @Published var isScanning = false
    @Published var devices: [DiscoveredDevice] = []
    @Published var linkState: LinkState = .idle
    @Published var activeDeviceID: UUID?
    @Published var temperature: Double?
    @Published var humidity: Double?
    @Published var log: [LogEntry] = []

    private var central: CBCentralManager!
    private var activePeripheral: CBPeripheral?
    private var wantsConnection = false

    private let serviceUUID = CBUUID(string: EnvironmentalSensing.serviceUUID)
    private let temperatureUUID = CBUUID(string: EnvironmentalSensing.temperatureUUID)
    private let humidityUUID = CBUUID(string: EnvironmentalSensing.humidityUUID)

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    // MARK: - Scanning

    func startScan() {
        guard central.state == .poweredOn else { return }
        devices.removeAll { $0.id != activeDeviceID }
        central.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        isScanning = true
        addLog("Scan started")
    }

    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        addLog("Scan stopped")
    }

    // MARK: - Connection

    func connect(_ id: UUID) {
        guard let device = devices.first(where: { $0.id == id }) else { return }
        if activeDeviceID == id, linkState == .connected || linkState == .connecting {
            return
        }
        disconnect()
        stopScan()
        wantsConnection = true
        activeDeviceID = id
        activePeripheral = device.peripheral
        temperature = nil
        humidity = nil
        linkState = .connecting
        device.peripheral.delegate = self
        central.connect(device.peripheral, options: nil)
        addLog("Connecting to \(device.name)")
    }

    func disconnect() {
        wantsConnection = false
        if let peripheral = activePeripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        activePeripheral = nil
        activeDeviceID = nil
        linkState = .idle
    }

    // MARK: - Helpers

    private func addLog(_ text: String) {
        log.insert(LogEntry(time: Date(), text: text), at: 0)
        if log.count > 100 {
            log.removeLast(log.count - 100)
        }
    }

    private func sortDevices() {
        devices.sort { lhs, rhs in
            if lhs.hasEnvironmentalService != rhs.hasEnvironmentalService {
                return lhs.hasEnvironmentalService
            }
            return lhs.rssi > rhs.rssi
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn {
            startScan()
        } else {
            isScanning = false
            if activePeripheral != nil {
                linkState = .failed("Bluetooth is off")
            }
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let rssi = RSSI.intValue
        guard rssi != 127 else { return } // 127 means "RSSI not available"

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasService = services.contains(serviceUUID)
        let now = Date()

        if let index = devices.firstIndex(where: { $0.id == peripheral.identifier }) {
            // Advertisements arrive many times per second; refresh at most once a second.
            guard now.timeIntervalSince(devices[index].lastSeen) >= 1 else { return }
            devices[index].rssi = rssi
            devices[index].lastSeen = now
            if let advertisedName {
                devices[index].name = advertisedName
            }
            if hasService {
                devices[index].hasEnvironmentalService = true
            }
        } else {
            devices.append(
                DiscoveredDevice(
                    id: peripheral.identifier,
                    peripheral: peripheral,
                    name: advertisedName ?? peripheral.name ?? "Unnamed",
                    rssi: rssi,
                    hasEnvironmentalService: hasService,
                    lastSeen: now
                )
            )
        }
        sortDevices()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        linkState = .connected
        addLog("Connected, discovering services")
        peripheral.discoverServices([serviceUUID])
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        linkState = .failed(error?.localizedDescription ?? "unknown error")
        addLog("Connect failed: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        guard peripheral.identifier == activeDeviceID else { return }
        if wantsConnection {
            // A pending connect has no timeout in CoreBluetooth, so this
            // reconnects as soon as the sensor is back in range.
            linkState = .reconnecting
            addLog("Link lost, waiting to reconnect")
            central.connect(peripheral, options: nil)
        } else {
            linkState = .idle
            addLog("Disconnected")
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            addLog("Service discovery failed: \(error.localizedDescription)")
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            addLog("Environmental Sensing Service (0x181A) not found on this device")
            return
        }
        peripheral.discoverCharacteristics([temperatureUUID, humidityUUID], for: service)
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            addLog("Characteristic discovery failed: \(error.localizedDescription)")
            return
        }
        for characteristic in service.characteristics ?? [] {
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
        addLog("Subscribed to \(service.characteristics?.count ?? 0) characteristic(s)")
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        if characteristic.uuid == temperatureUUID {
            temperature = EnvironmentalSensing.temperatureCelsius(from: data)
        } else if characteristic.uuid == humidityUUID {
            humidity = EnvironmentalSensing.humidityPercent(from: data)
        }
    }
}
