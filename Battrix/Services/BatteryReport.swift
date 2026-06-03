import AppKit

/// Builds a plain-text battery report and copies it to the clipboard. Used by the "copy" toolbar
/// button — handy for sharing diagnostics or when buying/selling a used Mac.
@MainActor
enum BatteryReport {
    static func text(model: BatteryViewModel) -> String {
        var lines: [String] = ["Battrix Battery Report"]

        if let mac = model.mac {
            lines.append("\n[Mac Battery]")
            lines.append("Health: \(Fmt.percent(mac.healthPercent)) (\(mac.condition.label))")
            lines.append("Charge: \(Fmt.percent(mac.chargePercent))")
            lines.append("Full Charge Capacity: \(Fmt.mAh(mac.rawMaxCapacity))")
            lines.append("Design Capacity: \(Fmt.mAh(mac.designCapacity))")
            lines.append("Cycle Count: \(Fmt.count(mac.cycleCount))")
            lines.append("Temperature: \(Fmt.temperature(c: mac.temperatureC, f: mac.temperatureF))")
            lines.append("Power: \(Fmt.watts(mac.powerW))")
            lines.append("Voltage: \(Fmt.volts(mac.voltageV))")
            if let serial = mac.serial { lines.append("Serial: \(serial)") }
        }

        if model.adapter.isConnected, model.adapter.hasDetails {
            let a = model.adapter
            lines.append("\n[Power Adapter]")
            if let w = a.watts { lines.append("Wattage: \(w) W") }
            if let n = a.name { lines.append("Name: \(n)") }
            if a.voltageV != nil { lines.append("Voltage: \(Fmt.volts(a.voltageV))") }
            if a.currentA != nil { lines.append("Current: \(Fmt.amps(a.currentA))") }
        }

        for d in model.devices {
            lines.append("\n[\(d.displayName)]")
            lines.append("Health: \(Fmt.percent(d.healthPercent)) (\(d.condition.label))")
            lines.append("Cycle Count: \(Fmt.count(d.cycleCount))")
            lines.append("Full Charge Capacity: \(Fmt.mAh(d.fullChargeCapacity))")
            lines.append("Design Capacity: \(Fmt.mAh(d.designCapacity))")
            if let os = d.osVersion { lines.append("iOS: \(os)") }
        }

        return lines.joined(separator: "\n")
    }

    static func copy(model: BatteryViewModel) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text(model: model), forType: .string)
    }
}
