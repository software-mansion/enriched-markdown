import EnrichedMarkdown
import UIKit

/// Metrics and drawing for one typeset formula, in points. The closure
/// receives a top-left-origin context; the baseline sits at `y == ascent`.
final class MathTypesetResult {
    let width: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let draw: (CGContext) -> Void

    var size: CGSize {
        CGSize(width: width, height: ascent + descent)
    }

    init(
        width: CGFloat,
        ascent: CGFloat,
        descent: CGFloat,
        draw: @escaping (CGContext) -> Void
    ) {
        self.width = width
        self.ascent = ascent
        self.descent = descent
        self.draw = draw
    }
}

/// A typeset formula embedded in the text: the negative bounds origin sits
/// it on the baseline, and the raster is drawn lazily via
/// `image(forBounds:...)` and cached.
final class MathAttachment: NSTextAttachment, MarkdownPluginAttachment {
    let latex: String
    /// `$$…$$` as opposed to `$…$`; picks the restored delimiters.
    let isDisplay: Bool
    let isBlock: Bool

    private let result: MathTypesetResult
    private var cachedImage: UIImage?

    init(latex: String, isDisplay: Bool, isBlock: Bool, result: MathTypesetResult) {
        self.latex = latex
        self.isDisplay = isDisplay
        self.isBlock = isBlock
        self.result = result
        super.init(data: nil, ofType: nil)
        accessibilityLabel = latex
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func markdownText() -> String {
        delimiter + latex + delimiter
    }

    var literalText: String { latex }

    var sourceDelimiters: (opening: String, closing: String)? {
        (delimiter, delimiter)
    }

    private var delimiter: String {
        isDisplay ? "$$" : "$"
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFragmentRect: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        CGRect(
            x: 0,
            y: -ceil(result.descent),
            width: ceil(result.width),
            height: ceil(result.ascent) + ceil(result.descent)
        )
    }

    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        if let cachedImage {
            return cachedImage
        }
        guard imageBounds.width > 0, imageBounds.height > 0 else { return nil }

        let renderer = UIGraphicsImageRenderer(size: imageBounds.size)
        let rendered = renderer.image { rendererContext in
            result.draw(rendererContext.cgContext)
        }
        cachedImage = rendered
        return rendered
    }
}
