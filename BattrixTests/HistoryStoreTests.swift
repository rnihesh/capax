import Testing
import Foundation
import SwiftData
@testable import Battrix

/// History persistence + throttling.
///
/// Uses ONE shared in-memory container, cleared before each test. Creating a fresh `ModelContainer`
/// per test (Swift Testing makes a new suite instance per test) trips a SwiftData trap once several
/// containers for the same `@Model` exist in the process. `.serialized` so the shared container is
/// never touched concurrently.
@Suite(.serialized)
@MainActor
struct HistoryStoreTests {

    static let container: ModelContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(for: HistorySample.self, configurations: config)
    }()

    /// A store backed by the shared container, emptied first so each test starts clean.
    private func freshStore() throws -> HistoryStore {
        let context = Self.container.mainContext
        try context.delete(model: HistorySample.self)
        try context.save()
        return HistoryStore(context: context)
    }

    @Test func recordsAndQueriesInOrder() throws {
        let store = try freshStore()
        store.minInterval = 0
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        store.record(HistorySample(timestamp: t0, source: "mac", healthPercent: 90), now: t0)
        store.record(HistorySample(timestamp: t0.addingTimeInterval(60), source: "mac", healthPercent: 91),
                     now: t0.addingTimeInterval(60))
        let samples = store.samples(source: "mac", window: .all, now: t0.addingTimeInterval(120))
        #expect(samples.count == 2)
        #expect(samples.first?.healthPercent == 90)
        #expect(samples.last?.healthPercent == 91)
    }

    @Test func throttlesWithinIntervalWhenUnchanged() throws {
        let store = try freshStore()
        let t0 = Date(timeIntervalSince1970: 2_000_000)
        #expect(store.record(HistorySample(timestamp: t0, source: "mac", healthPercent: 90, cycleCount: 10), now: t0))
        let stored = store.record(
            HistorySample(timestamp: t0.addingTimeInterval(60), source: "mac", healthPercent: 90, cycleCount: 10),
            now: t0.addingTimeInterval(60)
        )
        #expect(stored == false)
        #expect(store.samples(source: "mac", window: .all, now: t0.addingTimeInterval(120)).count == 1)
    }

    @Test func meaningfulChangeBypassesThrottle() throws {
        let store = try freshStore()
        let t0 = Date(timeIntervalSince1970: 3_000_000)
        store.record(HistorySample(timestamp: t0, source: "mac", cycleCount: 10), now: t0)
        let stored = store.record(
            HistorySample(timestamp: t0.addingTimeInterval(30), source: "mac", cycleCount: 11),
            now: t0.addingTimeInterval(30)
        )
        #expect(stored == true)
    }

    @Test func windowFiltersOldSamples() throws {
        let store = try freshStore()
        store.minInterval = 0
        let now = Date(timeIntervalSince1970: 5_000_000)
        store.record(HistorySample(timestamp: now.addingTimeInterval(-10 * 86_400), source: "mac", healthPercent: 80), now: now)
        store.record(HistorySample(timestamp: now.addingTimeInterval(-1 * 86_400), source: "mac", healthPercent: 81), now: now)
        let week = store.samples(source: "mac", window: .week, now: now)
        #expect(week.count == 1)
    }

    @Test func separatesSourcesByDevice() throws {
        let store = try freshStore()
        store.minInterval = 0
        let now = Date(timeIntervalSince1970: 6_000_000)
        store.record(HistorySample(timestamp: now, source: "mac", healthPercent: 90), now: now)
        store.record(HistorySample(timestamp: now, source: "udid-1", healthPercent: 95), now: now)
        #expect(store.samples(source: "mac", window: .all, now: now).count == 1)
        #expect(store.samples(source: "udid-1", window: .all, now: now).count == 1)
    }

    @Test func emptyStoreReturnsNoSamples() throws {
        let store = try freshStore()
        #expect(store.latest(source: "mac") == nil)
        #expect(store.samples(source: "mac", window: .all).isEmpty)
    }
}
