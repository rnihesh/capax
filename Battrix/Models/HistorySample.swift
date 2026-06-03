import Foundation
import SwiftData

/// A single point-in-time battery reading, persisted locally for trend charts. One row per
/// meaningful sample (throttled by `HistoryStore`). `source` is "mac" or a device UDID so Mac and
/// iOS-device histories can be charted separately. Nothing here ever leaves the device.
@Model
final class HistorySample {
    var timestamp: Date
    var source: String
    var healthPercent: Double?
    var maxCapacity: Int?
    var cycleCount: Int?
    var temperatureC: Double?
    var chargePercent: Double?

    init(
        timestamp: Date,
        source: String,
        healthPercent: Double? = nil,
        maxCapacity: Int? = nil,
        cycleCount: Int? = nil,
        temperatureC: Double? = nil,
        chargePercent: Double? = nil
    ) {
        self.timestamp = timestamp
        self.source = source
        self.healthPercent = healthPercent
        self.maxCapacity = maxCapacity
        self.cycleCount = cycleCount
        self.temperatureC = temperatureC
        self.chargePercent = chargePercent
    }
}

/// Metric selectable in the history chart.
enum HistoryMetric: String, CaseIterable, Identifiable {
    case health = "Health"
    case capacity = "Capacity"
    case cycles = "Cycles"
    case temperature = "Temperature"
    var id: String { rawValue }

    var unit: String {
        switch self {
        case .health: return "%"
        case .capacity: return "mAh"
        case .cycles: return ""
        case .temperature: return "°C"
        }
    }
}

/// Time window for history queries.
enum HistoryWindow: String, CaseIterable, Identifiable {
    case day = "24h"
    case week = "7d"
    case month = "30d"
    case all = "All"
    var id: String { rawValue }

    /// Earliest timestamp to include, relative to `now`. `nil` = all time.
    func start(from now: Date) -> Date? {
        switch self {
        case .day:   return now.addingTimeInterval(-86_400)
        case .week:  return now.addingTimeInterval(-7 * 86_400)
        case .month: return now.addingTimeInterval(-30 * 86_400)
        case .all:   return nil
        }
    }
}
