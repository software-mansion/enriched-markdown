import EnrichedMarkdown
import UIKit

/// Renders math nodes as baseline-aligned image attachments inheriting the
/// surrounding font size and color; typeset failures fall back to the
/// delimited source text.
final class MathRenderer: NodeRenderer {
    typealias Typeset = (
        _ latex: String,
        _ displayMode: Bool,
        _ fontSize: CGFloat,
        _ color: UIColor
    ) -> MathTypesetResult?

    private let typeset: Typeset

    init(typeset: @escaping Typeset) {
        self.typeset = typeset
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let latex = node.flattenedText()
        guard !latex.isEmpty else { return }

        let isDisplay = node.type == .latexMathDisplay
        var attributes = context.getTextAttributes()
        let font = attributes[.font] as? UIFont ?? UIFont.preferredFont(forTextStyle: .body)
        let color = attributes[.foregroundColor] as? UIColor ?? UIColor.label

        guard let result = typeset(latex, isDisplay, font.pointSize, color) else {
            let delimiter = MathAttachment.delimiter(isDisplay: isDisplay)
            output.append(NSAttributedString(string: delimiter + latex + delimiter, attributes: attributes))
            return
        }

        attributes[.attachment] = MathAttachment(
            latex: latex,
            isDisplay: isDisplay,
            isBlock: context.rendersPluginBlock,
            result: result
        )
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
    }

    /// Synchronous and thread-safe, so it runs on the render queue; layouts are
    /// cached because every re-render (each streamed token) would repeat the FFI parse.
    static func raTeXTypeset(
        _ latex: String,
        displayMode: Bool,
        fontSize: CGFloat,
        color: UIColor
    ) -> MathTypesetResult? {
        // One-time font registration, kept off the main thread's first draw.
        _ = RaTeXFontLoader.ensureLoaded()
        guard let displayList = displayList(for: latex, displayMode: displayMode, color: color) else {
            return nil
        }

        let renderer = RaTeXRenderer(displayList: displayList, fontSize: fontSize)
        return MathTypesetResult(
            width: renderer.width,
            ascent: renderer.height,
            descent: renderer.depth
        ) { context in
            renderer.draw(in: context)
        }
    }

    private static let displayListCache: NSCache<NSString, DisplayListBox> = {
        let cache = NSCache<NSString, DisplayListBox>()
        cache.countLimit = 200
        return cache
    }()

    /// The layout is font-size independent (em units) but bakes in the
    /// color, so the color joins the key.
    private static func displayList(for latex: String, displayMode: Bool, color: UIColor) -> DisplayList? {
        let colorKey = color.cgColor.components?.map { "\($0)" }.joined(separator: ",") ?? "?"
        let key = "\(displayMode)|\(colorKey)|\(latex)" as NSString
        if let cached = displayListCache.object(forKey: key) {
            return cached.displayList
        }

        guard let displayList = try? RaTeXEngine.shared.parse(latex, displayMode: displayMode, color: color) else {
            return nil
        }
        displayListCache.setObject(DisplayListBox(displayList), forKey: key)
        return displayList
    }
}

private final class DisplayListBox {
    let displayList: DisplayList

    init(_ displayList: DisplayList) {
        self.displayList = displayList
    }
}
