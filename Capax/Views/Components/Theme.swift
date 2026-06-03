import SwiftUI

/// Shared visual vocabulary. Restraint is the rule: one accent, semantic color only for the
/// battery-condition signal, generous spacing, hairline dividers, system materials.
extension BatteryCondition {
    var tint: Color {
        switch self {
        case .excellent: return .green
        case .good:      return .mint
        case .fair:      return .yellow
        case .poor:      return .red
        case .unknown:   return .secondary
        }
    }
}

enum Metrics {
    static let cardCorner: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 10
}

/// Small-caps section header used above grouped cards.
struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}
