import Testing
import Foundation
@testable import Capax

/// Derived-metric math and IOKit dictionary parsing for the Mac battery. These are the honest
/// numbers users rely on — divide-by-zero and missing keys must never crash or report Inf.
///
/// `@MainActor` so every suite in this target runs on the one main actor. Swift Testing runs tests
/// in parallel by default; keeping them main-actor-isolated makes them effectively serial (no
/// `await` suspension points here), which prevents the SwiftData suite from being fetched
/// concurrently — SwiftData fetches are not safe under that concurrency and otherwise crash.
@MainActor
struct MacBatteryMathTests {

    @Test func healthIsFullChargeOverDesign() {
        let b = MacBattery(rawMaxCapacity: 4000, designCapacity: 5000)
        #expect(b.healthPercent == 80.0)
    }

    @Test func chargeIsCurrentOverMax() {
        let b = MacBattery(rawCurrentCapacity: 3000, rawMaxCapacity: 4000)
        #expect(b.chargePercent == 75.0)
    }

    @Test func powerIsVoltageTimesAmperage() {
        let b = MacBattery(voltageMV: 12000, amperageMA: -2000)
        let power = try! #require(b.powerW)
        #expect(abs(power - (-24.0)) < 0.0001)
    }

    @Test func zeroDesignDoesNotDivideByZero() {
        let b = MacBattery(rawMaxCapacity: 4000, designCapacity: 0)
        #expect(b.healthPercent == nil)
    }

    @Test func zeroMaxDoesNotDivideByZero() {
        let b = MacBattery(rawCurrentCapacity: 100, rawMaxCapacity: 0)
        #expect(b.chargePercent == nil)
    }

    @Test func missingValuesYieldNilNotCrash() {
        let b = MacBattery()
        #expect(b.healthPercent == nil)
        #expect(b.chargePercent == nil)
        #expect(b.powerW == nil)
        #expect(b.temperatureC == nil)
        #expect(b.serial == nil)
    }

    @Test func temperatureConvertsCentiCelsius() {
        let b = MacBattery(temperatureCentiC: 3012)
        #expect(abs((b.temperatureC ?? 0) - 30.12) < 0.0001)
        #expect(abs((b.temperatureF ?? 0) - 86.216) < 0.01)
    }

    @Test func conditionBandsFromHealth() {
        #expect(MacBattery(rawMaxCapacity: 95, designCapacity: 100).condition == .excellent)
        #expect(MacBattery(rawMaxCapacity: 85, designCapacity: 100).condition == .good)
        #expect(MacBattery(rawMaxCapacity: 70, designCapacity: 100).condition == .fair)
        #expect(MacBattery(rawMaxCapacity: 50, designCapacity: 100).condition == .poor)
        #expect(MacBattery().condition == .unknown)
    }

    // MARK: - Service dictionary parsing

    @Test func serviceParsesCapacityFallbackLadder() {
        let svc = MacBatteryService()
        // No AppleRaw keys → falls back to AbsoluteCapacity / MaxCapacity.
        let dict: [String: Any] = ["AbsoluteCapacity": 2500, "MaxCapacity": 3000, "DesignCapacity": 4000]
        let b = svc.parseBattery(dict)
        #expect(b.rawCurrentCapacity == 2500)
        #expect(b.rawMaxCapacity == 3000)
        #expect(b.designCapacity == 4000)
    }

    @Test func servicePrefersAppleRawKeys() {
        let svc = MacBatteryService()
        let dict: [String: Any] = [
            "AppleRawCurrentCapacity": 3500, "AbsoluteCapacity": 1,
            "AppleRawMaxCapacity": 4000, "MaxCapacity": 1,
            "DesignCapacity": 5000, "CycleCount": 142,
            "InstantAmperage": -1500, "Amperage": 999, "Voltage": 12600,
            "IsCharging": false, "ExternalConnected": false,
        ]
        let b = svc.parseBattery(dict)
        #expect(b.rawCurrentCapacity == 3500)
        #expect(b.rawMaxCapacity == 4000)
        #expect(b.cycleCount == 142)
        #expect(b.amperageMA == -1500)   // InstantAmperage preferred over Amperage
        #expect(b.healthPercent == 80.0)
    }

    @Test func serviceParsesAdapterDetails() {
        let svc = MacBatteryService()
        let dict: [String: Any] = [
            "ExternalConnected": true,
            "AdapterDetails": [
                "Watts": 96, "Name": " 96W USB-C Power Adapter ",
                "AdapterVoltage": 20000, "Current": 4700,
                "Manufacturer": "Apple", "SerialString": "ABC123",
            ],
        ]
        let a = svc.parseAdapter(dict)
        #expect(a.isConnected)
        #expect(a.watts == 96)
        #expect(a.name == "96W USB-C Power Adapter")   // trimmed
        #expect(a.voltageV == 20.0)
        #expect(a.currentA == 4.7)
        #expect(a.manufacturer == "Apple")
    }

    @Test func adapterDisconnectedWhenNoExternal() {
        let svc = MacBatteryService()
        let a = svc.parseAdapter(["ExternalConnected": false])
        #expect(!a.isConnected)
        #expect(!a.hasDetails)
    }

    @Test func decodesBatteryIDFromManufacturerData() {
        // Two length-prefixed ASCII fragments: 0x03 "ABC", 0x02 "DE".
        var bytes: [UInt8] = [0x03]; bytes += Array("ABC".utf8)
        bytes += [0x02]; bytes += Array("DE".utf8)
        let id = MacBatteryService.decodeBatteryID(Data(bytes))
        #expect(id == "ABC-DE")
    }

    @Test func batteryIDNilForEmptyData() {
        #expect(MacBatteryService.decodeBatteryID(nil) == nil)
        #expect(MacBatteryService.decodeBatteryID(Data()) == nil)
    }
}
