import Foundation

/// Abstraction over "read a connected iOS device's battery". Allows the view model to be driven by
/// a stub in tests/previews and by `LibimobiledeviceReader` in production. `Sendable` so polling
/// (which spawns subprocesses) can run off the main actor.
protocol IOSDeviceReader: Sendable {
    /// Whether the underlying tooling is available at all.
    var isToolingAvailable: Bool { get }
    /// Poll currently-connected devices and return an honest connection state.
    func poll() -> DeviceConnection
}

// MARK: - Pure parsing (shared, fully unit-tested against fixtures)

enum IOSPlistParsing {

    /// Parse `ideviceinfo -x` XML into the identity fields of an `IOSDeviceBattery`.
    static func applyDeviceInfo(_ data: Data, into device: inout IOSDeviceBattery) {
        guard let dict = plistDict(data) else { return }
        device.name = dict["DeviceName"] as? String
        device.productType = dict["ProductType"] as? String
        device.osVersion = dict["ProductVersion"] as? String
        device.serial = dict["SerialNumber"] as? String
        if let pt = device.productType { device.marketingName = IOSModelNames.name(for: pt) }
    }

    /// Parse `idevicediagnostics ioregentry AppleSmartBattery` (or `AppleARMPMUCharger`) XML into
    /// the battery fields. Tolerates the entry being either the root dict or nested one level.
    static func applyBatteryIORegistry(_ data: Data, into device: inout IOSDeviceBattery) {
        guard let root = plistDict(data) else { return }
        let entry = batteryEntry(in: root)

        device.fullChargeCapacity = (entry["AppleRawMaxCapacity"] as? Int) ?? (entry["MaxCapacity"] as? Int)
        device.currentCapacity = (entry["AppleRawCurrentCapacity"] as? Int) ?? (entry["CurrentCapacity"] as? Int)
        device.designCapacity = entry["DesignCapacity"] as? Int
        device.cycleCount = entry["CycleCount"] as? Int
        device.temperatureCentiC = entry["Temperature"] as? Int
        device.voltageMV = entry["Voltage"] as? Int
        device.isCharging = entry["IsCharging"] as? Bool
    }

    /// True when the IORegistry output carried no usable battery numbers — caller should try the
    /// `AppleARMPMUCharger` fallback entry (iPhone 7 and older).
    static func isBatteryEntryEmpty(_ data: Data) -> Bool {
        guard let root = plistDict(data) else { return true }
        let entry = batteryEntry(in: root)
        return (entry["AppleRawMaxCapacity"] ?? entry["MaxCapacity"]) == nil
            && entry["DesignCapacity"] == nil
            && entry["CycleCount"] == nil
    }

    // MARK: helpers

    private static func plistDict(_ data: Data) -> [String: Any]? {
        (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }

    /// idevicediagnostics sometimes wraps the entry under a top-level key; find the dict that holds
    /// the battery keys, falling back to the root.
    private static func batteryEntry(in root: [String: Any]) -> [String: Any] {
        if root["AppleRawMaxCapacity"] != nil || root["DesignCapacity"] != nil || root["CycleCount"] != nil {
            return root
        }
        for value in root.values {
            if let nested = value as? [String: Any],
               nested["AppleRawMaxCapacity"] != nil || nested["DesignCapacity"] != nil || nested["CycleCount"] != nil {
                return nested
            }
        }
        return root
    }
}
