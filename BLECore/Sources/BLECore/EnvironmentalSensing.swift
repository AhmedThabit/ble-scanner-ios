import Foundation

/// Parsers for the Bluetooth SIG Environmental Sensing Service (0x181A).
/// Pure Foundation code, so it builds and tests on Linux as well as iOS.
public enum EnvironmentalSensing {
    public static let serviceUUID = "181A"
    public static let temperatureUUID = "2A6E"
    public static let humidityUUID = "2A6F"

    /// Temperature characteristic (0x2A6E): sint16, little endian, 0.01 degC.
    /// The value 0x8000 means "not known".
    public static func temperatureCelsius(from data: Data) -> Double? {
        guard let raw = littleEndianUInt16(data) else { return nil }
        if raw == 0x8000 { return nil }
        return Double(Int16(bitPattern: raw)) / 100.0
    }

    /// Humidity characteristic (0x2A6F): uint16, little endian, 0.01 %.
    /// The value 0xFFFF means "not known".
    public static func humidityPercent(from data: Data) -> Double? {
        guard let raw = littleEndianUInt16(data) else { return nil }
        if raw == 0xFFFF { return nil }
        return Double(raw) / 100.0
    }

    static func littleEndianUInt16(_ data: Data) -> UInt16? {
        guard data.count >= 2 else { return nil }
        let low = UInt16(data[data.startIndex])
        let high = UInt16(data[data.startIndex + 1])
        return (high << 8) | low
    }
}
