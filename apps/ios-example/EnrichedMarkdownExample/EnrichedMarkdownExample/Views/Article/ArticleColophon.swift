import SwiftUI

/// Foot of the page: a rule, the library's mark, and one line on what was
/// rendered above it.
struct ArticleColophon: View {
    // MARK: - Properties

    let palette: ArticlePalette
    let gutter: CGFloat

    // MARK: - Views

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Rectangle()
                .fill(palette.rule)
                .frame(height: 1)

            HStack(alignment: .top, spacing: 13) {
                mark

                VStack(alignment: .leading, spacing: 5) {
                    Text("ENRICHED MARKDOWN")
                        .font(.articleLabel(11))
                        .tracking(1.7)
                        .foregroundStyle(palette.heading)

                    Text("Prose, LaTeX, figures, tables and code — one markdown source, rendered natively on iOS.")
                        .font(.articleMeta(12))
                        .lineSpacing(4)
                        .foregroundStyle(palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, gutter)
    }

    @ViewBuilder
    private var mark: some View {
        if let logo = Image(bundledPNG: "logo_icon") {
            logo
                .resizable()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

// MARK: -

#Preview {
    ArticleColophon(palette: .light, gutter: 24)
        .background(ArticlePalette.light.paper)
}
