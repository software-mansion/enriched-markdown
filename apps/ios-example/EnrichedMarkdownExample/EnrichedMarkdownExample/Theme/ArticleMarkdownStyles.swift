import EnrichedMarkdown
import EnrichedMarkdownLaTeX
import SwiftUI

/// Editorial palette for the Article screen: warm paper, near-black ink and a
/// single clay accent, in a light and a dark cut.
///
/// Two explicit sets rather than semantic colors: `foregroundStyle(Color)`
/// resolves to a static `UIColor` at theme-build time, so a light/dark swap has
/// to come from rebuilding the theme. The article also wants a warm paper
/// ground that `UIColor.systemBackground` does not provide.
struct ArticlePalette: Equatable {
    /// Page ground.
    let paper: Color
    /// Raised-but-quiet ground: blockquotes, table headers, chips.
    let surface: Color
    /// Alternating table rows — one step from `paper`, never two.
    let surfaceAlt: Color
    let body: Color
    let heading: Color
    let muted: Color
    let rule: Color
    /// Links, inline code, bullets — the one saturated color on the page.
    let accent: Color
    /// The accent where it decorates rather than signals: quote bar, monogram.
    let accentSoft: Color
    /// Marker wash behind a highlighted span — the accent diluted into the
    /// paper, never a stationery yellow, which would fight the clay.
    let highlight: Color
    /// Ink on that wash: a touch darker than `body`, so the span reads as
    /// emphasis and not merely as a colored rectangle.
    let highlightInk: Color
    let codeText: Color
    let codeBackground: Color
    let codeBorder: Color

    static let light = ArticlePalette(
        paper: Color(red: 250 / 255, green: 249 / 255, blue: 245 / 255),
        surface: Color(red: 240 / 255, green: 238 / 255, blue: 230 / 255),
        surfaceAlt: Color(red: 246 / 255, green: 244 / 255, blue: 237 / 255),
        body: Color(red: 43 / 255, green: 42 / 255, blue: 38 / 255),
        heading: Color(red: 20 / 255, green: 20 / 255, blue: 19 / 255),
        muted: Color(red: 122 / 255, green: 118 / 255, blue: 108 / 255),
        rule: Color(red: 226 / 255, green: 222 / 255, blue: 211 / 255),
        accent: Color(red: 189 / 255, green: 93 / 255, blue: 58 / 255),
        accentSoft: Color(red: 217 / 255, green: 119 / 255, blue: 87 / 255),
        highlight: Color(red: 246 / 255, green: 219 / 255, blue: 196 / 255),
        highlightInk: Color(red: 56 / 255, green: 36 / 255, blue: 25 / 255),
        codeText: Color(red: 232 / 255, green: 230 / 255, blue: 223 / 255),
        codeBackground: Color(red: 38 / 255, green: 38 / 255, blue: 36 / 255),
        codeBorder: Color(red: 58 / 255, green: 57 / 255, blue: 53 / 255)
    )

    static let dark = ArticlePalette(
        paper: Color(red: 26 / 255, green: 26 / 255, blue: 24 / 255),
        surface: Color(red: 35 / 255, green: 35 / 255, blue: 32 / 255),
        surfaceAlt: Color(red: 30 / 255, green: 30 / 255, blue: 28 / 255),
        body: Color(red: 214 / 255, green: 211 / 255, blue: 201 / 255),
        heading: Color(red: 245 / 255, green: 243 / 255, blue: 238 / 255),
        muted: Color(red: 143 / 255, green: 138 / 255, blue: 128 / 255),
        rule: Color(red: 54 / 255, green: 53 / 255, blue: 48 / 255),
        accent: Color(red: 224 / 255, green: 138 / 255, blue: 107 / 255),
        accentSoft: Color(red: 224 / 255, green: 138 / 255, blue: 107 / 255),
        highlight: Color(red: 78 / 255, green: 48 / 255, blue: 35 / 255),
        highlightInk: Color(red: 245 / 255, green: 225 / 255, blue: 210 / 255),
        codeText: Color(red: 226 / 255, green: 224 / 255, blue: 217 / 255),
        codeBackground: Color(red: 19 / 255, green: 19 / 255, blue: 18 / 255),
        codeBorder: Color(red: 46 / 255, green: 45 / 255, blue: 41 / 255)
    )

    static func forScheme(_ scheme: ColorScheme) -> ArticlePalette {
        scheme == .dark ? .dark : .light
    }
}

/// The article's markdown theme: Newsreader on warm paper, one clay accent,
/// and a 30pt baseline the whole page is measured against.
///
/// The serif is deliberate — KaTeX typesets math in a Computer Modern-like
/// serif, so serif prose lets the formulas sit in the paragraph instead of
/// looking pasted onto it.
///
/// `figureHeight` is the rendered height of block images. Attachments take a
/// fixed height rather than an aspect ratio, so the caller measures the text
/// column and passes the height the figures were drawn for.
func ArticleMarkdownTheme(_ palette: ArticlePalette, figureHeight: CGFloat) -> MarkdownTheme {
    MarkdownTheme {
        Paragraph()
            .fontFamily(ArticleFont.serif, size: 18)
            .foregroundStyle(palette.body)
            .lineHeight(30)
            .marginBottom(20)

        Heading(1)
            .fontFamily(ArticleFont.display, size: 34)
            .foregroundStyle(palette.heading)
            .lineHeight(41)
            .marginBottom(12)

        Heading(2)
            .fontFamily(ArticleFont.serifSemibold, size: 26)
            .foregroundStyle(palette.heading)
            .lineHeight(33)
            .marginTop(44)
            .marginBottom(14)

        Heading(3)
            .fontFamily(ArticleFont.serifSemibold, size: 20)
            .foregroundStyle(palette.heading)
            .lineHeight(27)
            .marginTop(32)
            .marginBottom(8)

        // Set in italic, so `**Abstract.**` inside it resolves to the family's
        // real bold-italic face rather than a synthesized slant.
        Blockquote()
            .fontFamily(ArticleFont.serifItalic, size: 18)
            .foregroundStyle(palette.body)
            .lineHeight(30)
            .borderColor(palette.accentSoft)
            .borderWidth(2)
            .backgroundStyle(palette.surface)
            .gapWidth(20)
            .marginTop(6)
            .marginBottom(26)

        List()
            .fontFamily(ArticleFont.serif, size: 18)
            .foregroundStyle(palette.body)
            .lineHeight(30)
            .bulletColor(palette.accentSoft)
            .bulletSize(5)
            .markerColor(palette.muted)
            .markerMinWidth(20)
            .gapWidth(12)
            .marginLeft(20)
            .marginBottom(24)

        // Grotesk headers: a serif at 12pt in a narrow cell turns to mush.
        Table()
            .fontFamily(ArticleFont.serif, size: 15)
            .foregroundStyle(palette.body)
            .lineHeight(25)
            .headerFontFamily(ArticleFont.label, size: 12)
            .headerTextColor(palette.heading)
            .headerBackground(palette.surface)
            .rowEvenBackground(palette.surfaceAlt)
            .rowOddBackground(palette.paper)
            .borderColor(palette.rule)
            .borderWidth(1)
            .borderRadius(12)
            .cellPaddingHorizontal(14)
            .cellPaddingVertical(12)
            .marginTop(8)
            .marginBottom(28)

        // `CodeBlock.fontSize` already pins the monospaced design.
        CodeBlock()
            .fontSize(13.5)
            .foregroundStyle(palette.codeText)
            .backgroundStyle(palette.codeBackground)
            .borderColor(palette.codeBorder)
            .borderWidth(1)
            .borderRadius(14)
            .padding(18)
            .lineHeight(22)
            .marginTop(6)
            .marginBottom(28)

        // `Code` already defaults `fontDesign` to `.monospaced`.
        Code()
            .foregroundStyle(palette.accent)
            .backgroundStyle(palette.surface)

        BlockImage()
            .height(figureHeight)
            .borderRadius(14)
            .marginTop(10)
            .marginBottom(10)

        Link()
            .foregroundStyle(palette.accent)
            .underline(true)

        Strong()
            .foregroundStyle(palette.heading)

        ThematicBreak()
            .color(palette.rule)
            .height(1)
            .marginTop(44)
            .marginBottom(36)

        // Display math gets the same square-edged ground as the blockquote —
        // `MathBlock` has no border or corner radius, so the quote's language
        // is the one it can speak. The panel earns its keep on the long
        // formulas: it bounds the region that scrolls, so a clipped edge reads
        // as more-to-the-right rather than as a rendering fault.
        MathBlock()
            .fontSize(19)
            .foregroundStyle(palette.heading)
            .background(palette.surface)
            .padding(16)
            .marginTop(4)
            .marginBottom(20)
            .textAlignment(.center)

        InlineMath()
            .foregroundStyle(palette.body)

        // The wash is painted over the whole 30pt line box, so it wants to be
        // close to the paper; the ink does the emphasizing.
        Highlight()
            .foregroundStyle(palette.highlightInk)
            .background(palette.highlight)
    }
}
