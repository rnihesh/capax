import Foundation

/// Centralized, locale-aware formatting for battery values. Keeps view code free of inline
/// string formatting and guarantees consistent units everywhere (window + menu bar + history).
enum Fmt {
    static func percent(_ value: Double?, decimals: Int = 0) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(decimals)f%%", value)
    }

    static func mAh(_ value: Int?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted()) mAh"
    }

    static func watts(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign = value > 0.05 ? "+" : (value < -0.05 ? "−" : "")
        return String(format: "%@%.1f W", sign, abs(value))
    }

    static func volts(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f V", value)
    }

    static func amps(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2f A", value)
    }

    static func milliamps(_ value: Int?) -> String {
        guard let value else { return "—" }
        let sign = value > 0 ? "+" : (value < 0 ? "−" : "")
        return "\(sign)\(abs(value)) mA"
    }

    static func temperature(c: Double?, f: Double?) -> String {
        guard let c, let f else { return "—" }
        return String(format: "%.1f°C  ·  %.0f°F", c, f)
    }

    static func count(_ value: Int?) -> String {
        guard let value else { return "—" }
        return value.formatted()
    }

    static func yesNo(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "Yes" : "No"
    }
}
