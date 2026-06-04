import Testing
import Foundation
@testable import Capax

/// Parsing of libimobiledevice tool output. This is the tested seam, Process invocation is thin,
/// the plist parsing is where correctness lives. Health is computed, never trusted from the device.
/// `@MainActor` to keep the whole target serial (see MacBatteryMathTests for why).
@MainActor
struct IOSBatteryParsingTests {

    // MARK: fixtures (inline XML plists matching real tool output shapes)

    static let deviceInfoXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>DeviceName</key><string>Nihesh's iPhone</string>
      <key>ProductType</key><string>iPhone15,2</string>
      <key>ProductVersion</key><string>17.5.1</string>
      <key>SerialNumber</key><string>F2LXXXXXXX</string>
    </dict></plist>
    """

    static let batteryXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>AppleRawMaxCapacity</key><integer>3200</integer>
      <key>AppleRawCurrentCapacity</key><integer>2560</integer>
      <key>DesignCapacity</key><integer>3279</integer>
      <key>CycleCount</key><integer>238</integer>
      <key>Temperature</key><integer>3050</integer>
      <key>IsCharging</key><false/>
    </dict></plist>
    """

    // Nested-under-a-key shape that idevicediagnostics sometimes emits.
    static let nestedBatteryXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>AppleSmartBattery</key><dict>
      <key>AppleRawMaxCapacity</key><integer>3000</integer>
      <key>DesignCapacity</key><integer>3500</integer>
      <key>CycleCount</key><integer>500</integer>
    </dict></dict></plist>
    """

    static let emptyBatteryXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict><key>SomethingElse</key><string>x</string></dict></plist>
    """

    private func data(_ s: String) -> Data { s.data(using: .utf8)! }

    // MARK: tests

    @Test func parsesDeviceIdentity() {
        var d = IOSDeviceBattery(udid: "abc")
        IOSPlistParsing.applyDeviceInfo(data(Self.deviceInfoXML), into: &d)
        #expect(d.name == "Nihesh's iPhone")
        #expect(d.productType == "iPhone15,2")
        #expect(d.osVersion == "17.5.1")
        #expect(d.serial == "F2LXXXXXXX")
        #expect(d.marketingName == "iPhone 14 Pro")  // resolved from product type
    }

    @Test func parsesBatteryAndComputesHealth() {
        var d = IOSDeviceBattery(udid: "abc")
        IOSPlistParsing.applyBatteryIORegistry(data(Self.batteryXML), into: &d)
        #expect(d.fullChargeCapacity == 3200)
        #expect(d.designCapacity == 3279)
        #expect(d.cycleCount == 238)
        let health = try! #require(d.healthPercent)
        #expect(abs(health - 97.59) < 0.1)
        let charge = try! #require(d.chargePercent)
        #expect(abs(charge - 80.0) < 0.1)
        #expect(d.temperatureC == 30.5)
    }

    @Test func parsesNestedBatteryEntry() {
        var d = IOSDeviceBattery(udid: "abc")
        IOSPlistParsing.applyBatteryIORegistry(data(Self.nestedBatteryXML), into: &d)
        #expect(d.fullChargeCapacity == 3000)
        #expect(d.designCapacity == 3500)
        #expect(d.cycleCount == 500)
    }

    @Test func detectsEmptyEntryForFallback() {
        #expect(IOSPlistParsing.isBatteryEntryEmpty(data(Self.emptyBatteryXML)) == true)
        #expect(IOSPlistParsing.isBatteryEntryEmpty(data(Self.batteryXML)) == false)
    }

    @Test func malformedPlistDoesNotCrash() {
        var d = IOSDeviceBattery(udid: "abc")
        IOSPlistParsing.applyDeviceInfo(data("not a plist"), into: &d)
        IOSPlistParsing.applyBatteryIORegistry(data("<garbage>"), into: &d)
        #expect(d.name == nil)
        #expect(d.fullChargeCapacity == nil)
        #expect(IOSPlistParsing.isBatteryEntryEmpty(data("nonsense")) == true)
    }

    @Test func unknownProductTypeFallsBackGracefully() {
        #expect(IOSModelNames.name(for: "iPhone99,9") == "iPhone")
        #expect(IOSModelNames.name(for: "iPad99,9") == "iPad")
        #expect(IOSModelNames.name(for: "iPhone15,2") == "iPhone 14 Pro")
    }
}
