import Foundation

/// Coarse signal bucket for showing RSSI to a user.
public enum SignalQuality: String, Equatable {
    case excellent
    case good
    case fair
    case weak

    public init(rssi: Int) {
        switch rssi {
        case (-60)...: self = .excellent
        case (-75)..<(-60): self = .good
        case (-88)..<(-75): self = .fair
        default: self = .weak
        }
    }

    /// Number of bars (1...4) for a signal indicator.
    public var bars: Int {
        switch self {
        case .excellent: return 4
        case .good: return 3
        case .fair: return 2
        case .weak: return 1
        }
    }
}

/// Checks a temperature against an allowed range, for threshold alerts.
public struct TemperatureRange: Equatable {
    public let minimum: Double
    public let maximum: Double

    public init(minimum: Double, maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public func contains(_ value: Double) -> Bool {
        value >= minimum && value <= maximum
    }
}
