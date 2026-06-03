import Foundation

/// Battery + identity for a connected iPhone/iPad, read over USB via libimobiledevice.
/// Health is computed from raw capacity exactly like the Mac — we never trust a device-reported
/// "100%" health key and never fake/repair values.
struct IOSDeviceBattery: Equatable, Identifiable {
    var udid: String
    var id: String { udid }

    // Identity (from `ideviceinfo`)
    var name: String?
    var productType: String?      // e.g. "iPhone15,2"
    var marketingName: String?    // resolved from productType, e.g. "iPhone 14 Pro"
    var osVersion: String?
    var serial: String?

    // Battery (from `idevicediagnostics ioregentry AppleSmartBattery`)
    var designCapacity: Int?
    var fullChargeCapacity: Int?   // AppleRawMaxCapacity
    var currentCapacity: Int?      // AppleRawCurrentCapacity
    var cycleCount: Int?
    var temperatureCentiC: Int?
    var voltageMV: Int?
    var isCharging: Bool?

    var healthPercent: Double? {
        guard let full = fullChargeCapacity, let design = designCapacity, design > 0 else { return nil }
        return Double(full) / Double(design) * 100
    }

    var chargePercent: Double? {
        guard let current = currentCapacity, let full = fullChargeCapacity, full > 0 else { return nil }
        return Double(current) / Double(full) * 100
    }

    var temperatureC: Double? {
        guard let t = temperatureCentiC else { return nil }
        return Double(t) / 100.0
    }

    var condition: BatteryCondition {
        BatteryCondition(healthPercent: healthPercent, cycleCount: cycleCount)
    }

    /// Best human-readable device name available.
    var displayName: String {
        name ?? marketingName ?? productType ?? "iOS Device"
    }
}

/// The state of iOS-device reading, surfaced honestly in the UI. Never a silent empty.
enum DeviceConnection: Equatable {
    case noDevice                     // nothing plugged in
    case toolingMissing               // libimobiledevice tools not found (bundled or on PATH)
    case detectedUntrusted(udid: String) // device seen but not paired/trusted
    case connected([IOSDeviceBattery])   // one or more devices read successfully
    case failed(String)               // tool ran but errored
}
