import Foundation

/// Power adapter details, parsed from the battery service's `AdapterDetails` dictionary.
struct AdapterInfo: Equatable {
    var watts: Int?
    var name: String?
    var voltageMV: Int?
    var currentMA: Int?
    var serial: String?
    var manufacturer: String?
    var isConnected: Bool

    var voltageV: Double? {
        guard let mv = voltageMV else { return nil }
        return Double(mv) / 1000.0
    }

    var currentA: Double? {
        guard let ma = currentMA else { return nil }
        return Double(ma) / 1000.0
    }

    /// True when an adapter is plugged in and reporting any detail worth showing.
    var hasDetails: Bool {
        watts != nil || name != nil || voltageMV != nil || currentMA != nil
    }

    static let disconnected = AdapterInfo(isConnected: false)
}
