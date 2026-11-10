import BLECore
import SwiftUI

struct DeviceDetailView: View {
    @EnvironmentObject private var ble: BLEManager
    let deviceID: UUID
    let deviceName: String

    /// Example acceptable range (cold-chain 2 to 8 degC) used to flag violations.
    private let allowedRange = TemperatureRange(minimum: 2, maximum: 8)

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    var body: some View {
        List {
            Section("Connection") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(ble.linkState.label)
                        .foregroundStyle(statusColor)
                }
                if ble.activeDeviceID == deviceID {
                    Button("Disconnect", role: .destructive) {
                        ble.disconnect()
                    }
                } else {
                    Button("Connect") {
                        ble.connect(deviceID)
                    }
                }
            }

            Section {
                HStack {
                    Text("Temperature")
                    Spacer()
                    Text(temperatureText)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(temperatureColor)
                }
                HStack {
                    Text("Humidity")
                    Spacer()
                    Text(humidityText)
                        .font(.title2.monospacedDigit())
                }
            } header: {
                Text("Environmental sensing")
            } footer: {
                Text("Temperature turns red outside \(Int(allowedRange.minimum)) to \(Int(allowedRange.maximum)) °C.")
            }

            Section("Log") {
                ForEach(ble.log) { entry in
                    Text("\(Self.timeFormatter.string(from: entry.time))  \(entry.text)")
                        .font(.caption.monospaced())
                }
            }
        }
        .navigationTitle(deviceName)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ble.connect(deviceID)
        }
    }

    private var temperatureText: String {
        guard let value = ble.temperature else { return "--" }
        return String(format: "%.2f °C", value)
    }

    private var humidityText: String {
        guard let value = ble.humidity else { return "--" }
        return String(format: "%.2f %%", value)
    }

    private var temperatureColor: Color {
        guard let value = ble.temperature else { return .secondary }
        return allowedRange.contains(value) ? .primary : .red
    }

    private var statusColor: Color {
        switch ble.linkState {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .failed: return .red
        case .idle: return .secondary
        }
    }
}
