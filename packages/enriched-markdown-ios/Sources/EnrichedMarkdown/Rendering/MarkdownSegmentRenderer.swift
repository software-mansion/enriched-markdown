import UIKit

/// One vertically stacked piece of a rendered document. Today every document
/// renders as a single text segment; table support will interleave natively
/// rendered table segments between text segments.
struct RenderedMarkdownSegment: Identifiable, Equatable {
    enum Content: Equatable {
        case text(NSAttributedString)
    }

    /// Position within the rendered document. Segments are only consumed as
    /// a whole array from one render pass, so positional identity is stable.
    let id: Int
    let content: Content
}

enum MarkdownSegmentRenderer {
    /// The placeholder for blank input: a single empty text segment, so the
    /// view tree (and its sizing) matches what an empty attributed string
    /// produced before segmentation existed.
    static let empty: [RenderedMarkdownSegment] = [
        RenderedMarkdownSegment(id: 0, content: .text(NSAttributedString()))
    ]

    static func renderSegments(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:]
    ) -> [RenderedMarkdownSegment] {
        let text = MarkdownRenderer.render(
            markdown,
            config: config,
            flags: flags,
            imageRequestHeaders: imageRequestHeaders
        )
        return [RenderedMarkdownSegment(id: 0, content: .text(text))]
    }
}
