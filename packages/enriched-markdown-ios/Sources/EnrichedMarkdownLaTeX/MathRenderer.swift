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

    private let config: MarkdownStyleConfig
    private let typeset: Typeset
    private let fallback = MathSourceFallbackRenderer()

    init(config: MarkdownStyleConfig, typeset: @escaping Typeset = MathRenderer.raTeXTypeset) {
        self.config = config
        self.typeset = typeset
    }

    func render(node: MarkdownASTNode, into output: NSMutableAttributedString, context: RenderContext) {
        let latex = node.latexSourceText()
        guard !latex.isEmpty else { return }

        let isDisplay = node.type == .latexMathDisplay
        let blockStyle = context.getBlockStyle()
        let font = blockStyle?.font
            ?? config.paragraph.font
            ?? UIFont.preferredFont(forTextStyle: .body)
        let color = blockStyle?.color ?? config.paragraph.foregroundColor ?? UIColor.label

        guard let result = typeset(latex, isDisplay, font.pointSize, color) else {
            fallback.render(node: node, into: output, context: context)
            return
        }

        let attachment = MathAttachment(
            latex: latex,
            isDisplay: isDisplay,
            isBlock: context.rendersPluginBlock,
            result: result
        )
        var attributes = context.getTextAttributes()
        attributes[.attachment] = attachment
        SourceOffsetAnnotator.tagSourceRange(in: &attributes, of: node)
        output.append(NSAttributedString(string: "\u{FFFC}", attributes: attributes))
    }

    /// Synchronous and thread-safe, so it can run on the render queue.
    static func raTeXTypeset(
        _ latex: String,
        displayMode: Bool,
        fontSize: CGFloat,
        color: UIColor
    ) -> MathTypesetResult? {
        _ = RaTeXFontLoader.ensureLoaded()
        guard let displayList = try? RaTeXEngine.shared.parse(
            latex,
            displayMode: displayMode,
            color: color
        ) else {
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
}
