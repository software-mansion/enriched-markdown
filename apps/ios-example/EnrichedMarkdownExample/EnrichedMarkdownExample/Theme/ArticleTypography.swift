import SwiftUI

/// Type families bundled for the Article screen.
///
/// Newsreader carries the prose: a warm transitional serif whose optical-size
/// axis was instanced into two cuts — a 16pt text cut for running copy and a
/// 48pt display cut, drawn with finer hairlines, for the masthead headline.
/// Space Grotesk handles the small mechanical labels (kicker, byline, caption,
/// table headers) that a serif sets poorly at 11-13pt.
///
/// Names are PostScript names; the files ship in `Resources/Fonts`.
enum ArticleFont {
    static let display = "NewsreaderDisplay-Regular"
    static let serif = "Newsreader-Regular"
    static let serifItalic = "Newsreader-Italic"
    static let serifSemibold = "Newsreader-SemiBold"
    static let label = "SpaceGrotesk-Medium"
    static let meta = "SpaceGrotesk-Regular"
}

extension Font {
    /// Headline cut — only above ~28pt, where its hairlines survive.
    static func articleDisplay(_ size: CGFloat) -> Font {
        .custom(ArticleFont.display, size: size)
    }

    static func articleSerif(_ size: CGFloat) -> Font {
        .custom(ArticleFont.serif, size: size)
    }

    static func articleSerifItalic(_ size: CGFloat) -> Font {
        .custom(ArticleFont.serifItalic, size: size)
    }

    /// Grotesk medium, for tracked-out labels and names.
    static func articleLabel(_ size: CGFloat) -> Font {
        .custom(ArticleFont.label, size: size)
    }

    /// Grotesk regular, for captions and secondary metadata.
    static func articleMeta(_ size: CGFloat) -> Font {
        .custom(ArticleFont.meta, size: size)
    }
}
