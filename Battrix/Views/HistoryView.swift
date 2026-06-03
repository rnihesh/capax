import SwiftUI
import SwiftData
import Charts

/// Local battery-history trends. Restrained Swift Charts line graph with metric + window pickers.
/// All data is local (SwiftData); nothing is uploaded.
struct HistoryView: View {
    @Query(sort: \HistorySample.timestamp, order: .forward) private var allSamples: [HistorySample]

    @State private var metric: HistoryMetric = .health
    @State private var window: HistoryWindow = .week
    @State private var source: String = "mac"

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
            controls

            if filtered.count < 2 {
                emptyState
            } else {
                chart
                    .frame(minHeight: 260)
                summaryRow
            }
            Spacer(minLength: 0)
        }
        .padding(Metrics.sectionSpacing)
        .onAppear { if !sources.contains(source), let first = sources.first { source = first } }
    }

    // MARK: subviews

    private var controls: some View {
        VStack(spacing: 10) {
            if sources.count > 1 {
                Picker("Source", selection: $source) {
                    ForEach(sources, id: \.self) { Text(sourceLabel($0)).tag($0) }
                }
                .pickerStyle(.menu)
            }
            Picker("Metric", selection: $metric) {
                ForEach(HistoryMetric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Range", selection: $window) {
                ForEach(HistoryWindow.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private var chart: some View {
        Chart(filtered) { sample in
            if let value = value(for: sample) {
                LineMark(
                    x: .value("Time", sample.timestamp),
                    y: .value(metric.rawValue, value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)

                AreaMark(
                    x: .value("Time", sample.timestamp),
                    y: .value(metric.rawValue, value)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor.opacity(0.12))
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis { AxisMarks(values: .automatic(desiredCount: 4)) }
        .chartYAxis { AxisMarks(position: .leading) }
    }

    private var summaryRow: some View {
        let values = filtered.compactMap { value(for: $0) }
        return HStack(spacing: 18) {
            stat("Latest", values.last)
            stat("Min", values.min())
            stat("Max", values.max())
            Spacer()
        }
        .font(.caption)
    }

    private func stat(_ label: String, _ value: Double?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).foregroundStyle(.secondary)
            Text(value.map { String(format: "%.1f%@", $0, metric.unit.isEmpty ? "" : " \(metric.unit)") } ?? "—")
                .monospacedDigit().fontWeight(.medium)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 30)).foregroundStyle(.secondary)
            Text("Not enough history yet")
                .font(.headline)
            Text("Battrix records a sample every few minutes while it runs. Leave it open and trends will appear here.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }

    // MARK: data

    private var sources: [String] {
        var s = Array(Set(allSamples.map(\.source)))
        // Keep "mac" first for stable ordering.
        s.sort { ($0 == "mac" ? 0 : 1, $0) < ($1 == "mac" ? 0 : 1, $1) }
        return s.isEmpty ? ["mac"] : s
    }

    private var filtered: [HistorySample] {
        let start = window.start(from: Date())
        return allSamples.filter { $0.source == source && (start == nil || $0.timestamp >= start!) }
    }

    private func value(for s: HistorySample) -> Double? {
        switch metric {
        case .health:      return s.healthPercent
        case .capacity:    return s.maxCapacity.map(Double.init)
        case .cycles:      return s.cycleCount.map(Double.init)
        case .temperature: return s.temperatureC
        }
    }

    private func sourceLabel(_ s: String) -> String {
        s == "mac" ? "This Mac" : "iOS Device"
    }
}
