import Foundation
import SwiftData

/// Persists throttled battery samples and serves windowed queries for the trend charts.
/// All access is on the main actor (SwiftData `ModelContext` is not Sendable).
///
/// Queries fetch all rows and filter in Swift rather than using `#Predicate`. History volume is
/// tiny (throttled to one row per source per few minutes), and this avoids SwiftData predicate
/// fragility while keeping the logic trivially testable.
@MainActor
final class HistoryStore {
    private let context: ModelContext

    /// Minimum spacing between stored samples for a given source, unless a meaningful change occurs.
    /// Keeps the store from bloating during the ~5s live-refresh loop.
    var minInterval: TimeInterval = 5 * 60   // 5 minutes

    init(context: ModelContext) {
        self.context = context
    }

    /// Record a sample if enough time has passed since the last one for this source, or if a
    /// meaningful metric changed (cycle count, or health by ≥0.1pt). Returns true when stored.
    @discardableResult
    func record(_ sample: HistorySample, now: Date = Date()) -> Bool {
        if let last = latest(source: sample.source) {
            let elapsed = now.timeIntervalSince(last.timestamp)
            let cycleChanged = sample.cycleCount != last.cycleCount
            let healthDelta = abs((sample.healthPercent ?? 0) - (last.healthPercent ?? 0))
            if elapsed < minInterval, !cycleChanged, healthDelta < 0.1 {
                return false
            }
        }
        context.insert(sample)
        try? context.save()
        return true
    }

    /// Most recent sample for a source, or nil.
    func latest(source: String) -> HistorySample? {
        allSorted().last { $0.source == source }
    }

    /// Samples for a source within a window, oldest first.
    func samples(source: String, window: HistoryWindow, now: Date = Date()) -> [HistorySample] {
        let start = window.start(from: now)
        return allSorted().filter { sample in
            sample.source == source && (start == nil || sample.timestamp >= start!)
        }
    }

    /// All samples, oldest first.
    private func allSorted() -> [HistorySample] {
        let descriptor = FetchDescriptor<HistorySample>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
