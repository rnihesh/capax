import SwiftUI

/// Connected iPhone/iPad battery. Every connection state renders an explicit, honest panel —
/// never a silent empty. Connected devices reuse the Mac's exact visual language.
struct IOSDeviceSection: View {
    let connection: DeviceConnection
    let toolingAvailable: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "iOS Device")
            content
        }
    }

    @ViewBuilder private var content: some View {
        switch connection {
        case .connected(let devices):
            ForEach(devices) { device in
                IOSDeviceCard(device: device)
            }
        case .noDevice:
            hint(icon: "iphone.gen3.slash",
                 title: "No device connected",
                 message: toolingAvailable
                    ? "Connect an iPhone or iPad with a cable to read its battery health."
                    : "Connect an iPhone or iPad to read its battery health.")
        case .detectedUntrusted:
            hint(icon: "lock.iphone",
                 title: "Trust required",
                 message: "Unlock the device and tap “Trust” when prompted, then it will appear here.")
        case .toolingMissing:
            hint(icon: "wrench.and.screwdriver",
                 title: "Device tools unavailable",
                 message: "iOS reading needs libimobiledevice. Release builds bundle it; for source builds run “brew install libimobiledevice”.")
        case .failed(let reason):
            hint(icon: "exclamationmark.triangle",
                 title: "Couldn’t read device",
                 message: reason)
        }
    }

    private func hint(icon: String, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.callout.weight(.medium))
                Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(Metrics.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.cardCorner)
                .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
        )
    }
}

/// A connected iOS device's battery card — same hero-ring vocabulary as the Mac, scaled down.
struct IOSDeviceCard: View {
    let device: IOSDeviceBattery

    var body: some View {
        SectionCard {
            HStack(alignment: .center, spacing: 14) {
                CompactRing(percent: device.healthPercent, condition: device.condition)
                VStack(alignment: .leading, spacing: 3) {
                    Text(device.displayName).font(.headline)
                    if let model = device.marketingName, model != device.displayName {
                        Text(model).font(.caption).foregroundStyle(.secondary)
                    }
                    if let os = device.osVersion {
                        Text("iOS \(os)").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(device.condition.label)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(device.condition.tint)
                }
                Spacer()
            }
            Divider()
            MetricRow(icon: "heart", label: "Health", value: Fmt.percent(device.healthPercent))
            MetricRow(icon: "arrow.triangle.2.circlepath", label: "Cycle Count", value: Fmt.count(device.cycleCount))
            MetricRow(icon: "bolt.batteryblock", label: "Full Charge Capacity", value: Fmt.mAh(device.fullChargeCapacity))
            MetricRow(icon: "square.dashed", label: "Design Capacity", value: Fmt.mAh(device.designCapacity))
            MetricRow(icon: "battery.75", label: "Charge", value: Fmt.percent(device.chargePercent))
            if device.temperatureCentiC != nil {
                MetricRow(icon: "thermometer.medium", label: "Temperature",
                          value: Fmt.temperature(c: device.temperatureC, f: device.temperatureC.map { $0 * 9/5 + 32 }))
            }
        }
    }
}

/// Smaller ring used inside device cards.
struct CompactRing: View {
    let percent: Double?
    let condition: BatteryCondition
    private var fraction: Double { max(0, min((percent ?? 0) / 100, 1)) }

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 7)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(condition.tint.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: fraction)
            Text(Fmt.percent(percent))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .frame(width: 56, height: 56)
    }
}
