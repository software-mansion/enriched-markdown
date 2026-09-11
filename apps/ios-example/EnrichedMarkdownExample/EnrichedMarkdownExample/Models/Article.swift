import Foundation

/// The one long-form document the example ships with.
///
/// Everything except `body` is masthead furniture the screen draws in SwiftUI;
/// `body` is the markdown the library renders.
struct Article {
    let kicker: String
    let title: String
    let deck: String
    let authorName: String
    let authorInitials: String
    let publishedOn: String
    let readingTime: String
    let heroImageName: String
    let heroCaption: String
    let body: String
}

extension Article {
    static var featured: Article {
        Article(
            kicker: "Field Theory",
            title: "The Shape of a Wave",
            deck: "Why light and matter obey almost the same equation — and what changes in the gap between them.",
            authorName: "Elena Marchetti",
            authorInitials: "EM",
            publishedOn: "September 2026",
            readingTime: "9 min read",
            heroImageName: "article_hero",
            heroCaption: "A transverse wave and its slower envelope, sampled on the uniform grid a solver steps over.",
            body: Bundle.main.articleMarkdown
        )
    }
}
