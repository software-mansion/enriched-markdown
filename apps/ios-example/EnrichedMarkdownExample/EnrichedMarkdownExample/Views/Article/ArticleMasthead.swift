import SwiftUI

/// The opening spread: kicker rule, display headline, deck, byline, and the
/// full-bleed hero figure that hands off to the markdown body.
struct ArticleMasthead: View {
    // MARK: - Properties

    let article: Article
    let palette: ArticlePalette
    let gutter: CGFloat
    /// Viewport size, used by the hero's parallax instead of `UIScreen`.
    let viewport: CGSize

    // MARK: - Views

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            kicker
                .padding(.horizontal, gutter)
                .padding(.top, 14)

            Text(article.title)
                .font(.articleDisplay(43))
                .tracking(-0.7)
                .lineSpacing(1)
                .foregroundStyle(palette.heading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, gutter)
                .padding(.top, 16)

            Text(article.deck)
                .font(.articleSerifItalic(19))
                .lineSpacing(6)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, gutter)
                .padding(.top, 14)

            byline
                .padding(.horizontal, gutter)
                .padding(.top, 24)

            Rectangle()
                .fill(palette.rule)
                .frame(height: 1)
                .padding(.horizontal, gutter)
                .padding(.top, 22)

            ArticleHeroFigure(
                imageName: article.heroImageName,
                caption: article.heroCaption,
                palette: palette,
                gutter: gutter,
                viewport: viewport
            )
            .padding(.top, 26)
        }
    }

    /// Tracked-out section label with a hairline running out to the margin.
    private var kicker: some View {
        HStack(spacing: 12) {
            Text(article.kicker.uppercased())
                .font(.articleLabel(11))
                .tracking(1.9)
                .foregroundStyle(palette.accent)

            Rectangle()
                .fill(palette.rule)
                .frame(height: 1)
        }
    }

    private var byline: some View {
        HStack(spacing: 13) {
            Text(article.authorInitials)
                .font(.articleLabel(13))
                .tracking(0.5)
                .foregroundStyle(palette.accent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(palette.accentSoft.opacity(0.15)))
                .overlay(Circle().strokeBorder(palette.accentSoft.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 3) {
                Text(article.authorName)
                    .font(.articleLabel(14))
                    .foregroundStyle(palette.heading)

                Text("\(article.publishedOn) · \(article.readingTime)")
                    .font(.articleMeta(12))
                    .foregroundStyle(palette.muted)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: -

/// Edge-to-edge hero image with a light parallax and a captioned figure line.
///
/// The image is drawn taller than its window and slid against the scroll, so
/// it drifts rather than tracks — enough to read as depth, not as motion.
struct ArticleHeroFigure: View {
    // MARK: - Properties

    let imageName: String
    let caption: String
    let palette: ArticlePalette
    let gutter: CGFloat
    let viewport: CGSize

    private let height: CGFloat = 218
    private let overdraw: CGFloat = 64

    // MARK: - Views

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { frame in
                image
                    .frame(width: frame.size.width, height: height + overdraw)
                    .offset(y: parallax(midY: frame.frame(in: .global).midY))
                    .frame(width: frame.size.width, height: height)
                    .clipped()
            }
            .frame(height: height)

            figureLine
                .padding(.horizontal, gutter)
        }
    }

    @ViewBuilder
    private var image: some View {
        if let hero = Image(bundledPNG: imageName) {
            hero.resizable().scaledToFill()
        } else {
            palette.surface
        }
    }

    private var figureLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Text("FIG. 1")
                .font(.articleLabel(10))
                .tracking(1.3)
                .foregroundStyle(palette.accent)

            Text(caption)
                .font(.articleMeta(12))
                .lineSpacing(3)
                .foregroundStyle(palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Methods

    /// Half the overdraw at most, so the image never uncovers its window.
    private func parallax(midY: CGFloat) -> CGFloat {
        let limit = overdraw / 2
        let travel = (midY - viewport.height / 2) / max(viewport.height, 1)
        return min(max(travel * limit, -limit), limit)
    }
}

// MARK: -

#Preview {
    ScrollView {
        ArticleMasthead(
            article: .featured,
            palette: .light,
            gutter: 24,
            viewport: CGSize(width: 393, height: 852)
        )
    }
    .background(ArticlePalette.light.paper)
}
