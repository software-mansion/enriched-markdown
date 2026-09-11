import SwiftUI

/// Hairline reading indicator pinned under the navigation bar.
struct ArticleReadingProgress: View {
    // MARK: - Properties

    /// 0…1, clamped by the caller.
    let progress: CGFloat
    let palette: ArticlePalette

    // MARK: - Views

    var body: some View {
        GeometryReader { frame in
            palette.accent
                .frame(width: frame.size.width * progress)
                .animation(.linear(duration: 0.08), value: progress)
        }
        .frame(height: 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.rule.opacity(0.6))
        .accessibilityHidden(true)
    }
}

// MARK: -

/// Distance the article has travelled under the navigation bar, reported by a
/// zero-height sentinel at the top of the scroll content.
struct ArticleScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Height of the whole scrolled column, for the progress denominator.
struct ArticleContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
