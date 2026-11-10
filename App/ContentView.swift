import BLECore
import CoreBluetooth
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var ble: BLEManager

    var body: some View {
        NavigationStack {
            List {
                if ble.bluetoothState != .poweredOn {
                    Section {
                        Label(bluetoothMessage, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    if ble.devices.isEmpty {
                        Text(ble.isScanning ? "Searching for devices..." : "No devices found yet.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(ble.devices) { device in
                        NavigationLink {
                            DeviceDetailView(deviceID: device.id, deviceName: device.name)
                        } label: {
                            DeviceRow(device: device)
                        }
                    }
                } header: {
                    Text("Nearby devices (\(ble.devices.count))")
                } footer: {
                    Text("Devices that advertise the Environmental Sensing Service are listed first.")
                }
            }
            .navigationTitle("BLE Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(ble.isScanning ? "Stop" : "Scan") {
                        if ble.isScanning {
                            ble.stopScan()
                        } else {
                            ble.startScan()
                        }
                    }
                    .disabled(ble.bluetoothState != .poweredOn)
                }
            }
        }
    }

    private var bluetoothMessage: String {
        switch ble.bluetoothState {
        case .poweredOff: return "Bluetooth is turned off."
        case .unauthorized: return "Bluetooth permission was denied. Enable it in Settings."
        case .unsupported: return "This device does not support Bluetooth Low Energy."
        case .resetting: return "Bluetooth is restarting."
        default: return "Waiting for Bluetooth..."
        }
    }
}

struct DeviceRow: View {
    let device: DiscoveredDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                if device.hasEnvironmentalService {
                    Text("Temperature / humidity sensor")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                SignalBars(quality: SignalQuality(rssi: device.rssi))
                Text("\(device.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SignalBars: View {
    let quality: SignalQuality

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(1...4, id: \.self) { bar in
                RoundedRectangle(cornerRadius: 1)
                    .fill(bar <= quality.bars ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 4, height: CGFloat(4 + bar * 3))
            }
        }
        .accessibilityLabel("Signal \(quality.rawValue)")
    }
}
