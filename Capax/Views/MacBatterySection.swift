import SwiftUI

/// The Mac battery: hero health ring + charge bar + detailed metric rows. Honest technical labels.
struct MacBatterySection: View {
    let battery: MacBattery

    var body: some View {
        VStack(spacing: Metrics.sectionSpacing) {
            HeroGaugeView(
                percent: battery.healthPercent,
                centerValue: Fmt.percent(battery.healthPercent),
                caption: "Battery Health",
                condition: battery.condition,
                subtitle: capacitySubtitle
            )

            HStack(spacing: 8) {
                Image(systemName: "heart.text.square")
                    .foregroundStyle(battery.condition.tint)
                Text(battery.condition.label)
                    .font(.callout.weight(.medium))
                    .foregroundStyle(battery.condition.tint)
            }

            ChargeBar(percent: battery.chargePercent, isCharging: battery.isCharging ?? false)
                .padding(.horizontal, 2)

            SectionCard("Capacity") {
                MetricRow(icon: "bolt.batteryblock", label: "Full Charge Capacity", value: Fmt.mAh(battery.rawMaxCapacity))
                MetricRow(icon: "square.dashed", label: "Design Capacity", value: Fmt.mAh(battery.designCapacity))
                MetricRow(icon: "battery.75", label: "Current Charge", value: Fmt.mAh(battery.rawCurrentCapacity))
            }

            SectionCard("Condition") {
                MetricRow(icon: "arrow.triangle.2.circlepath", label: "Cycle Count", value: Fmt.count(battery.cycleCount))
                MetricRow(icon: "thermometer.medium", label: "Temperature",
                          value: Fmt.temperature(c: battery.temperatureC, f: battery.temperatureF))
                if battery.amperageMA != nil || battery.voltageV != nil {
                    MetricRow(icon: "powermeter", label: "Power", value: Fmt.watts(battery.powerW))
                    MetricRow(icon: "bolt", label: "Voltage", value: Fmt.volts(battery.voltageV))
                    MetricRow(icon: "bolt.horizontal", label: "Amperage", value: Fmt.milliamps(battery.amperageMA))
                }
            }

            if battery.serial != nil || battery.batteryID != nil {
                SectionCard("Identity") {
                    if let id = battery.batteryID {
                        MetricRow(icon: "number", label: "Battery ID", value: id)
                    }
                    if let serial = battery.serial {
                        MetricRow(icon: "barcode", label: "Serial Number", value: serial)
                    }
                }
            }
        }
    }

    private var capacitySubtitle: String? {
        guard let full = battery.rawMaxCapacity, let design = battery.designCapacity else { return nil }
        return "\(full.formatted()) / \(design.formatted()) mAh"
    }
}
