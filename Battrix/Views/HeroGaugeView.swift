import SwiftUI

/// The app's visual signature: a custom-drawn ring showing the hero metric (battery health) with a
/// large legible value in the center. Bespoke arc + smooth fill — deliberately not a stock `Gauge`.
struct HeroGaugeView: View {
    let percent: Double?          // 0...100, the value the ring fills to
    let centerValue: String       // big number, e.g. "92%"
    let caption: String           // e.g. "Battery Health"
    let condition: BatteryCondition
    var subtitle: String? = nil   // e.g. "4521 / 4900 mAh"

    private var fraction: Double { max(0, min((percent ?? 0) / 100, 1)) }
    private let lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    condition.tint.gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: fraction)

            VStack(spacing: 2) {
                Text(centerValue)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                }
            }
        }
        .frame(width: 150, height: 150)
        .padding(.vertical, 4)
    }
}

/// A slim horizontal charge bar (current charge level), distinct from the health ring above.
struct ChargeBar: View {
    let percent: Double?
    let isCharging: Bool

    private var fraction: Double { max(0, min((percent ?? 0) / 100, 1)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isCharging ? "bolt.fill" : "battery.50")
                    .font(.caption)
                    .foregroundStyle(isCharging ? .green : .secondary)
                Text("Charge")
                    .font(.callout)
                Spacer()
                Text(Fmt.percent(percent))
                    .font(.callout.weight(.medium))
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary)
                    Capsule()
                        .fill(isCharging ? Color.green.gradient : Color.accentColor.gradient)
                        .frame(width: max(6, geo.size.width * fraction))
                        .animation(.easeInOut, value: fraction)
                }
            }
            .frame(height: 8)
        }
    }
}
