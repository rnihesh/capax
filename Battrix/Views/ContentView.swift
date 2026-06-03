import SwiftUI

/// Main window shell: a Summary / History tab switcher with a toolbar for refresh + copy report.
struct ContentView: View {
    @Environment(BatteryViewModel.self) private var model
    @State private var tab: Tab = .summary
    @State private var copied = false

    enum Tab: String, CaseIterable, Identifiable {
        case summary = "Summary"
        case history = "History"
        var id: String { rawValue }
        var icon: String { self == .summary ? "gauge.with.dots.needle.bottom.50percent" : "chart.xyaxis.line" }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Label(t.rawValue, systemImage: t.icon).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, Metrics.sectionSpacing)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            switch tab {
            case .summary: SummaryView()
            case .history: HistoryView()
            }
        }
        .frame(minWidth: 420, minHeight: 560)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    copyReport()
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                }
                .help("Copy battery report")

                Button {
                    model.refresh()
                    model.pollDevices()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh now")
            }
        }
        .navigationTitle("Battrix")
    }

    private func copyReport() {
        BatteryReport.copy(model: model)
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation { copied = false }
        }
    }
}
