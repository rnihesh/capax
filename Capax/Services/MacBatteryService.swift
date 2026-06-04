import Foundation
import IOKit

/// Source of Mac battery readings. Abstracted so the view model can be driven by a stub in tests.
protocol MacBatterySource {
    func read() -> (battery: MacBattery, adapter: AdapterInfo)?
}

/// Reads the Mac's internal battery from the IOKit `AppleSmartBattery` service.
///
/// The key-fallback ladders below encode real cross-model/silicon quirks, the same precedence
/// the original Capax used (e.g. `AppleRawCurrentCapacity` before `AbsoluteCapacity` before
/// `CurrentCapacity`). Preserve precedence when changing this; different Macs expose different keys.
struct MacBatteryService: MacBatterySource {

    /// Read a fresh snapshot, or `nil` when no battery service is present (e.g. a desktop Mac).
    func read() -> (battery: MacBattery, adapter: AdapterInfo)? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceNameMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return nil
        }

        return (parseBattery(dict), parseAdapter(dict))
    }

    // MARK: - Parsing (pure; exposed for tests via fixture dictionaries)

    func parseBattery(_ dict: [String: Any]) -> MacBattery {
        var b = MacBattery()

        b.rawCurrentCapacity = (dict["AppleRawCurrentCapacity"] as? Int)
            ?? (dict["AbsoluteCapacity"] as? Int)
            ?? (dict["CurrentCapacity"] as? Int)

        b.rawMaxCapacity = (dict["AppleRawMaxCapacity"] as? Int)
            ?? (dict["MaxCapacity"] as? Int)

        b.designCapacity = dict["DesignCapacity"] as? Int
        b.cycleCount = dict["CycleCount"] as? Int
        b.temperatureCentiC = dict["Temperature"] as? Int
        b.voltageMV = dict["Voltage"] as? Int
        b.amperageMA = (dict["InstantAmperage"] as? Int) ?? (dict["Amperage"] as? Int)
        b.isCharging = dict["IsCharging"] as? Bool
        b.fullyCharged = dict["FullyCharged"] as? Bool
        b.externalConnected = dict["ExternalConnected"] as? Bool

        if let batteryData = dict["BatteryData"] as? [String: Any],
           let lifetime = batteryData["LifetimeData"] as? [String: Any],
           let maxDischarge = lifetime["MaximumDischargeCurrent"] as? String {
            b.maxDischargeCurrentMA = Int(maxDischarge)
        }

        if let serial = dict["Serial"] as? String, !serial.isEmpty {
            b.serial = serial
        }

        b.batteryID = Self.decodeBatteryID(dict["ManufacturerData"] as? Data)

        return b
    }

    func parseAdapter(_ dict: [String: Any]) -> AdapterInfo {
        let connected = dict["ExternalConnected"] as? Bool ?? false
        guard let details = dict["AdapterDetails"] as? [String: Any] else {
            return AdapterInfo(isConnected: connected)
        }

        var a = AdapterInfo(isConnected: connected)
        a.watts = details["Watts"] as? Int
        if let name = (details["Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            a.name = name
        }
        a.voltageMV = details["AdapterVoltage"] as? Int
        a.currentMA = details["Current"] as? Int
        if let serial = details["SerialString"] as? String, !serial.isEmpty { a.serial = serial }
        if let mfr = details["Manufacturer"] as? String, !mfr.isEmpty { a.manufacturer = mfr }
        return a
    }

    /// `ManufacturerData` is a blob of length-prefixed ASCII strings. Decode defensively and join
    /// the printable fragments into a stable battery identifier. Returns nil if nothing decodes.
    static func decodeBatteryID(_ data: Data?) -> String? {
        guard let data, !data.isEmpty else { return nil }
        var pos = 0
        var parts: [String] = []
        while pos < data.count {
            let len = Int(data[pos])
            if pos < data.count - 1, len > 0, len < 20, pos + len < data.count {
                let range = (pos + 1)..<(pos + 1 + len)
                if let s = String(data: data.subdata(in: range), encoding: .ascii)?
                    .trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                    parts.append(s)
                }
                pos += 1 + len
            } else {
                pos += 1
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: "-")
    }
}
