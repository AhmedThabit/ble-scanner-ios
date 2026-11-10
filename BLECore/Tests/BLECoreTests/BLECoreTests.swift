import XCTest
@testable import BLECore

final class BLECoreTests: XCTestCase {
    func testPositiveTemperature() {
        // 2345 = 0x0929 -> 23.45 degC
        let value = EnvironmentalSensing.temperatureCelsius(from: Data([0x29, 0x09]))
        XCTAssertEqual(value ?? .nan, 23.45, accuracy: 0.001)
    }

    func testNegativeTemperature() {
        // -1850 = 0xF8C6 -> -18.50 degC
        let value = EnvironmentalSensing.temperatureCelsius(from: Data([0xC6, 0xF8]))
        XCTAssertEqual(value ?? .nan, -18.5, accuracy: 0.001)
    }

    func testTemperatureNotKnown() {
        XCTAssertNil(EnvironmentalSensing.temperatureCelsius(from: Data([0x00, 0x80])))
    }

    func testTooShortPayload() {
        XCTAssertNil(EnvironmentalSensing.temperatureCelsius(from: Data([0x01])))
        XCTAssertNil(EnvironmentalSensing.humidityPercent(from: Data()))
    }

    func testHumidity() {
        // 5512 = 0x1588 -> 55.12 %
        let value = EnvironmentalSensing.humidityPercent(from: Data([0x88, 0x15]))
        XCTAssertEqual(value ?? .nan, 55.12, accuracy: 0.001)
    }

    func testHumidityNotKnown() {
        XCTAssertNil(EnvironmentalSensing.humidityPercent(from: Data([0xFF, 0xFF])))
    }

    func testParsingASliceWithNonZeroStartIndex() {
        let buffer = Data([0xAA, 0xBB, 0x29, 0x09])
        let slice = buffer.subdata(in: 2..<4)
        let dropped = buffer.dropFirst(2)
        XCTAssertEqual(EnvironmentalSensing.temperatureCelsius(from: slice) ?? .nan, 23.45, accuracy: 0.001)
        XCTAssertEqual(EnvironmentalSensing.temperatureCelsius(from: dropped) ?? .nan, 23.45, accuracy: 0.001)
    }

    func testSignalQualityBuckets() {
        XCTAssertEqual(SignalQuality(rssi: -45), .excellent)
        XCTAssertEqual(SignalQuality(rssi: -60), .excellent)
        XCTAssertEqual(SignalQuality(rssi: -61), .good)
        XCTAssertEqual(SignalQuality(rssi: -80), .fair)
        XCTAssertEqual(SignalQuality(rssi: -95), .weak)
        XCTAssertEqual(SignalQuality(rssi: -95).bars, 1)
    }

    func testTemperatureRange() {
        let coldChain = TemperatureRange(minimum: 2, maximum: 8)
        XCTAssertTrue(coldChain.contains(2))
        XCTAssertTrue(coldChain.contains(5.5))
        XCTAssertFalse(coldChain.contains(8.01))
        XCTAssertFalse(coldChain.contains(-1))
    }
}
