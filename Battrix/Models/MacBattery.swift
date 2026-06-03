import Foundation

/// A typed snapshot of the Mac's internal battery, read from the IOKit `AppleSmartBattery`
/// service. Raw values are stored as the hardware reports them; every user-facing metric is a
/// pure computed property so the math stays testable and honest (no faked/repaired values).
struct MacBattery: Equatable {
    // Capacity (mAh)
    var rawCurrentCapacity: Int?   // AppleRawCurrentCapacity
    var rawMaxCapacity: Int?       // AppleRawMaxCapacity  (current full-charge capacity)
    var designCapacity: Int?       // DesignCapacity       (factory maximum)

    // Wear / lifetime
    var cycleCount: Int?
    var maxDischargeCurrentMA: Int?

    // Instantaneous electrical state
    var temperatureCentiC: Int?    // Temperature, centi-°C
    var voltageMV: Int?            // Voltage, millivolts
    var amperageMA: Int?           // InstantAmperage/Amperage, signed mA (+charge / -discharge)

    // Flags
    var isCharging: Bool?
    var fullyCharged: Bool?
    var externalConnected: Bool?

    // Identity
    var serial: String?
    var batteryID: String?

    // MARK: - Derived metrics (pure)

    /// Battery health: current full-charge capacity ÷ factory design capacity. `nil` when
    /// either value is missing or zero (never divide by zero, never report Inf).
    var healthPercent: Double? {
        guard let maxCap = rawMaxCapacity, let design = designCapacity, design > 0 else { return nil }
        return Double(maxCap) / Double(design) * 100
    }

    /// Charge level from raw capacity values (more accurate than the OS-reported percent).
    var chargePercent: Double? {
        guard let current = rawCurrentCapacity, let maxCap = rawMaxCapacity, maxCap > 0 else { return nil }
        return Double(current) / Double(maxCap) * 100
    }

    var temperatureC: Double? {
        guard let t = temperatureCentiC else { return nil }
        return Double(t) / 100.0
    }

    var temperatureF: Double? {
        guard let c = temperatureC else { return nil }
        return c * 9 / 5 + 32
    }

    var voltageV: Double? {
        guard let mv = voltageMV else { return nil }
        return Double(mv) / 1000.0
    }

    /// Instantaneous power in watts, signed (+charging / -discharging). `nil` when inputs missing.
    var powerW: Double? {
        guard let mv = voltageMV, let ma = amperageMA else { return nil }
        return Double(mv) * Double(ma) / 1_000_000.0
    }

    /// Qualitative health band used for color + condition labels.
    var condition: BatteryCondition {
        BatteryCondition(healthPercent: healthPercent, cycleCount: cycleCount)
    }

    static let empty = MacBattery()
}

/// Health band shared by the Mac battery and connected iOS devices. Drives the only place we use
/// semantic color: green / yellow / red signal the user's battery condition, nothing decorative.
enum BatteryCondition: Equatable {
    case excellent   // healthy, low wear
    case good
    case fair
    case poor        // service recommended
    case unknown

    init(healthPercent: Double?, cycleCount: Int?) {
        guard let health = healthPercent else { self = .unknown; return }
        switch health {
        case 90...:    self = .excellent
        case 80..<90:  self = .good
        case 60..<80:  self = .fair
        default:       self = .poor
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good:      return "Good"
        case .fair:      return "Fair"
        case .poor:      return "Service Recommended"
        case .unknown:   return "Unknown"
        }
    }
}
