import EnrichedMarkdown
import UIKit

/// Metrics and drawing for one typeset formula, in points. The closure
/// receives a top-left-origin context; the baseline sits at `y == ascent`.
struct MathTypesetResult {
    let width: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    let draw: (CGContext) -> Void
}

/// The full-width panel a root-level display formula sits in: the
/// background fills the line, the formula is inset by `padding` and aligned
/// inside; one wider than the panel starts at the left inset and clips.
struct MathPanelStyle: Equatable {
    var backgroundColor: UIColor?
    var padding: CGFloat = 0
    var textAlignment: NSTextAlignment = .natural

    func contentOriginX(formulaWidth: CGFloat, panelWidth: CGFloat) -> CGFloat {
        let available = panelWidth - padding * 2
        guard formulaWidth < available else { return padding }
        switch textAlignment {
        case .center:
            return padding + floor((available - formulaWidth) / 2)
        case .right:
            return padding + available - formulaWidth
        default:
            return padding
        }
    }
}

/// A typeset formula embedded in the text: the negative bounds origin sits
/// it on the baseline, and the raster is drawn lazily via
/// `image(forBounds:...)`. The formula is rasterized once; a panel is
/// re-composed around it whenever the line width changes.
final class MathAttachment: NSTextAttachment, MarkdownPluginAttachment {
    let latex: String
    /// `$$…$$` as opposed to `$…$`; picks the restored delimiters.
    let isDisplay: Bool
    /// Set for root-level display math, which then spans the line.
    let panel: MathPanelStyle?

    private let result: MathTypesetResult
    private var panelImage: UIImage?

    private lazy var formulaImage: UIImage? = {
        guard formulaSize.width > 0, formulaSize.height > 0 else { return nil }
        return UIGraphicsImageRenderer(size: formulaSize).image { result.draw($0.cgContext) }
    }()

    static func delimiter(isDisplay: Bool) -> String {
        isDisplay ? "$$" : "$"
    }

    init(latex: String, isDisplay: Bool, result: MathTypesetResult, panel: MathPanelStyle? = nil) {
        self.latex = latex
        self.isDisplay = isDisplay
        self.result = result
        self.panel = panel
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

    var isBlock: Bool { panel != nil }

    var literalText: String { latex }

    var sourceDelimiters: (opening: String, closing: String)? {
        (delimiter, delimiter)
    }

    private var delimiter: String {
        Self.delimiter(isDisplay: isDisplay)
    }

    private var formulaSize: CGSize {
        CGSize(width: ceil(result.width), height: ceil(result.ascent) + ceil(result.descent))
    }

    override func attachmentBounds(
        for textContainer: NSTextContainer?,
        proposedLineFragment lineFragmentRect: CGRect,
        glyphPosition position: CGPoint,
        characterIndex charIndex: Int
    ) -> CGRect {
        let size = formulaSize
        guard let panel else {
            return CGRect(x: 0, y: -ceil(result.descent), width: size.width, height: size.height)
        }
        let inset = panel.padding * 2
        return CGRect(
            x: 0,
            y: -(ceil(result.descent) + panel.padding),
            width: max(lineFragmentRect.width, size.width + inset),
            height: size.height + inset
        )
    }

    override func image(
        forBounds imageBounds: CGRect,
        textContainer: NSTextContainer?,
        characterIndex charIndex: Int
    ) -> UIImage? {
        guard let panel else { return formulaImage }
        if let panelImage, panelImage.size == imageBounds.size {
            return panelImage
        }
        guard imageBounds.width > 0, imageBounds.height > 0 else { return nil }

        let rendered = UIGraphicsImageRenderer(size: imageBounds.size).image { rendererContext in
            if let backgroundColor = panel.backgroundColor {
                backgroundColor.setFill()
                rendererContext.fill(CGRect(origin: .zero, size: imageBounds.size))
            }
            let originX = panel.contentOriginX(formulaWidth: formulaSize.width, panelWidth: imageBounds.width)
            formulaImage?.draw(at: CGPoint(x: originX, y: panel.padding))
        }
        panelImage = rendered
        return rendered
    }
}
