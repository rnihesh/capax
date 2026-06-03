import SwiftUI

/// A titled group of metric rows inside a material card. The core building block of every section.
struct SectionCard<Content: View>: View {
    let title: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title { SectionHeader(title: title) }
            VStack(spacing: Metrics.rowSpacing) {
                content
            }
            .padding(Metrics.cardPadding)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.cardCorner)
                    .strokeBorder(.separator.opacity(0.5), lineWidth: 0.5)
            )
        }
    }
}
