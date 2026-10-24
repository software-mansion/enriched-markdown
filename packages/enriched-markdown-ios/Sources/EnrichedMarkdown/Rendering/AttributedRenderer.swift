import UIKit

package final class AttributedRenderer {
    private let config: MarkdownStyleConfiguration
    private let factory: RendererFactory
    /// Root-level plugin block node types and the margins each declares.
    private let rootBlockMargins: [NodeType: BlockMargins]

    init(
        config: MarkdownStyleConfiguration,
        imageRequestHeaders: [String: String] = [:],
        plugins: [any MarkdownRenderPlugin] = [],
        writingDirection: MarkdownWritingDirection = .firstStrong,
        layoutDirection: UIUserInterfaceLayoutDirection = .leftToRight,
        codeBlockLayout: MarkdownCodeBlockLayout = .wrapping
    ) {
        self.config = config
        self.factory = RendererFactory(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins,
            writingDirection: writingDirection,
            layoutDirection: layoutDirection,
            codeBlockLayout: codeBlockLayout
        )
        self.rootBlockMargins = plugins.reduce(into: [:]) { margins, plugin in
            for type in plugin.rootBlockNodeTypes where margins[type] == nil {
                margins[type] = plugin.blockMargins(for: type, config: config)
            }
        }
    }

    func renderRoot(_ root: MarkdownASTNode) -> NSMutableAttributedString {
        let context = makeRootContext()
        let output = NSMutableAttributedString()
        renderBlocks(root.children, into: output, context: context)
        context.clearBlockStyle()
        TrailingSpacing.strip(from: output, codeBlockPadding: config.codeBlock.padding ?? 0)
        finishBlocks(in: output, range: NSRange(location: 0, length: output.length), context: context)
        return output
    }

    package func makeRootContext() -> RenderContext {
        let context = RenderContext()
        let paragraphFont = config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        let paragraphColor = config.paragraph.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: paragraphFont, color: paragraphColor)
        return context
    }

    package func renderBlocks(_ blocks: [MarkdownASTNode], into output: NSMutableAttributedString, context: RenderContext) {
        for child in blocks {
            // A synthetic paragraph gives bare plugin block nodes their
            // block margins and alignment.
            if let margins = rootBlockMargins[child.type] {
                context.pluginBlockMargins = margins
                let paragraph = MarkdownASTNode(type: .paragraph, children: [child])
                factory.renderer(for: .paragraph).render(node: paragraph, into: output, context: context)
                context.pluginBlockMargins = nil
                continue
            }
            factory.renderer(for: child.type).render(node: child, into: output, context: context)
        }
    }

    package func finishBlocks(in output: NSMutableAttributedString, range: NSRange, context: RenderContext) {
        BaselineShiftRenderer.applyShifts(to: output, in: range, context: context, config: config)
        SpoilerConcealment.conceal(output, in: range)
        factory.applyWritingDirection(to: output, in: range)
    }
}

extension AttributedRenderer {
    package convenience init(inputs: MarkdownRenderInputs) {
        self.init(
            config: inputs.config,
            imageRequestHeaders: inputs.imageRequestHeaders,
            plugins: inputs.plugins.values,
            writingDirection: inputs.writingDirection,
            layoutDirection: UIUserInterfaceLayoutDirection(inputs.layoutDirection),
            codeBlockLayout: inputs.codeBlockLayout
        )
    }
}
