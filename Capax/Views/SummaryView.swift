import SwiftUI

/// The live overview: Mac battery, adapter, and any connected iOS device.
struct SummaryView: View {
    @Environment(BatteryViewModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(spacing: Metrics.sectionSpacing) {
                if let mac = model.mac {
                    MacBatterySection(battery: mac)
                    AdapterSection(adapter: model.adapter)
                } else {
                    EmptyBatteryView()
                }

                IOSDeviceSection(connection: model.connection, toolingAvailable: model.isToolingAvailable)
            }
            .padding(Metrics.sectionSpacing)
        }
    }
}

/// Shown on a Mac with no internal battery (e.g. a desktop), honest, not a spinner forever.
struct EmptyBatteryView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.batteryblock")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)
            Text("No battery detected")
                .font(.headline)
            Text("This Mac doesn’t report an internal battery. Connect an iOS device below to read its battery.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}
