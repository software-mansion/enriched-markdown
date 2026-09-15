import EnrichedMarkdown
import UIKit
import UniformTypeIdentifiers

/// Metrics and drawing for one typeset formula, in points. The closure
/// receives a top-left-origin context; the baseline sits at `y == ascent`.
struct MathTypesetResult {
    let width: CGFloat
    let ascent: CGFloat
    let descent: CGFloat
    /// Pre-rasterized off the main thread; nil draws lazily.
    var image: UIImage?
    let draw: (CGContext) -> Void

    var size: CGSize {
        CGSize(width: ceil(width), height: ceil(ascent) + ceil(descent))
    }

    func rasterize() -> UIImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        return UIGraphicsImageRenderer(size: size).image { draw($0.cgContext) }
    }
}

/// The full-width panel a root-level display formula sits in: the
/// background fills the line, the formula is inset by `padding` and aligned
/// inside; one wider than the panel starts at the left inset and scrolls.
struct MathPanelStyle: Equatable {
    var backgroundColor: UIColor?
    var padding: CGFloat = 0
    var textAlignment: NSTextAlignment = .natural

    /// The formula plus its inset on every side.
    func contentSize(formulaSize: CGSize) -> CGSize {
        CGSize(width: formulaSize.width + padding * 2, height: formulaSize.height + padding * 2)
    }

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

/// A typeset formula embedded in the text, sat on the baseline by its
/// negative bounds origin. Inline math draws as a rasterized image;
/// root-level display math (`panel != nil`) is hosted in a scrolling
/// `MathBlockView`, or under TextKit 1, which installs no view, drawn as a
/// panel image that clips the overflow.
final class MathAttachment: NSTextAttachment, MarkdownPluginAttachment {
    /// Must be a resolvable UTI, or NSTextAttachment silently drops it.
    static let fileType: String = UTType(
        filenameExtension: "enriched-markdown-math"
    )?.identifier ?? "public.data"

    /// The only way UIKit installs the view; overriding `viewProvider(for:)`
    /// on the attachment breaks it.
    private static let providerRegistration: Void = {
        NSTextAttachment.registerViewProviderClass(
            MathAttachmentViewProvider.self,
            forFileType: MathAttachment.fileType
        )
    }()

    let latex: String
    /// `$$…$$` as opposed to `$…$`; picks the restored delimiters.
    let isDisplay: Bool
    /// Set for root-level display math, which then spans the line.
    let panel: MathPanelStyle?

    /// TextKit 2 recreates the provider view whenever the block re-enters
    /// the viewport; the horizontal scroll position survives here.
    var preservedContentOffset: CGPoint = .zero

    private let result: MathTypesetResult
    private var panelImage: UIImage?

    /// The formula rasterized once at its natural size.
    private(set) lazy var formulaImage: UIImage? = result.image ?? result.rasterize()

    static func delimiter(isDisplay: Bool) -> String {
        isDisplay ? "$$" : "$"
    }

    /// `accessibilityLabel` is fully resolved here because the base
    /// package's element builder reads it generically.
    init(
        latex: String,
        isDisplay: Bool,
        result: MathTypesetResult,
        panel: MathPanelStyle? = nil,
        accessibilityLabel: String
    ) {
        self.latex = latex
        self.isDisplay = isDisplay
        self.result = result
        self.panel = panel
        if panel != nil {
            _ = Self.providerRegistration
            // fileType only persists with non-nil contents; the data is never read.
            super.init(data: Data("math".utf8), ofType: Self.fileType)
        } else {
            super.init(data: nil, ofType: nil)
            // Else TextKit 2 hosts each inline formula in an image view, rebuilt per layout pass.
            allowsTextAttachmentView = false
        }
        self.accessibilityLabel = accessibilityLabel
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

    var formulaSize: CGSize { result.size }

    /// TextKit 2 sizes the hosted view from this too; overriding its own
    /// bounds method instead stops UIKit from installing the view.
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
        return CGRect(
            x: 0,
            y: -(ceil(result.descent) + panel.padding),
            width: lineFragmentRect.width,
            height: panel.contentSize(formulaSize: size).height
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
