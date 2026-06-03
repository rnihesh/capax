import SwiftUI

/// The menu-bar item's label: live charge %, a charging glyph, and watts when plugged in.
/// This is Capax's always-glanceable edge over window-only competitors.
struct MenuBarLabel: View {
    var model: BatteryViewModel

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: glyph)
            if let pct = model.mac?.chargePercent {
                Text("\(Int(pct))%").monospacedDigit()
            }
        }
    }

    private var glyph: String {
        guard let mac = model.mac else { return "bolt.batteryblock" }
        if mac.isCharging == true { return "battery.100.bolt" }
        let pct = mac.chargePercent ?? 0
        switch pct {
        case ..<13: return "battery.0"
        case ..<38: return "battery.25"
        case ..<63: return "battery.50"
        case ..<88: return "battery.75"
        default:    return "battery.100"
        }
    }
}

/// The popover shown from the menu bar: compact summary + open-window + quit. Shares the one model.
struct MenuBarView: View {
    @Environment(BatteryViewModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let mac = model.mac {
                HStack(spacing: 12) {
                    CompactRing(percent: mac.healthPercent, condition: mac.condition)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Battery Health").font(.caption).foregroundStyle(.secondary)
                        Text(Fmt.percent(mac.healthPercent))
                            .font(.title2.weight(.semibold)).monospacedDigit()
                        Text(mac.condition.label)
                            .font(.caption.weight(.medium)).foregroundStyle(mac.condition.tint)
                    }
                    Spacer()
                }

                ChargeBar(percent: mac.chargePercent, isCharging: mac.isCharging ?? false)

                Divider()

                VStack(spacing: 6) {
                    miniRow("Cycle Count", Fmt.count(mac.cycleCount))
                    miniRow("Temperature", Fmt.temperature(c: mac.temperatureC, f: mac.temperatureF))
                    if mac.amperageMA != nil { miniRow("Power", Fmt.watts(mac.powerW)) }
                }
            } else {
                Text("No battery detected").font(.callout).foregroundStyle(.secondary)
            }

            if !model.devices.isEmpty {
                Divider()
                ForEach(model.devices) { d in
                    HStack {
                        Image(systemName: "iphone")
                        Text(d.displayName).font(.callout)
                        Spacer()
                        Text(Fmt.percent(d.healthPercent)).monospacedDigit()
                            .foregroundStyle(d.condition.tint)
                    }
                }
            }

            Divider()

            HStack {
                Button("Open Capax") { openWindow(id: "main"); NSApp.activate(ignoringOtherApps: true) }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)
        }
        .padding(14)
        .frame(width: 280)
    }

    private func miniRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.callout).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.callout).monospacedDigit()
        }
    }
}
