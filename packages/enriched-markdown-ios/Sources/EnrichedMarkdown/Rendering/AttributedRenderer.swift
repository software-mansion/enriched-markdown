import UIKit

final class AttributedRenderer {
    private let config: MarkdownStyleConfig
    private let factory: RendererFactory
    private let rootBlockTypes: Set<NodeType>

    init(
        config: MarkdownStyleConfig,
        imageRequestHeaders: [String: String] = [:],
        plugins: [any MarkdownRenderPlugin] = []
    ) {
        self.config = config
        self.factory = RendererFactory(
            config: config,
            imageRequestHeaders: imageRequestHeaders,
            plugins: plugins
        )
        self.rootBlockTypes = plugins.reduce(into: []) { $0.formUnion($1.rootBlockNodeTypes) }
    }

    func renderRoot(_ root: MarkdownASTNode) -> NSMutableAttributedString {
        let context = RenderContext()
        let output = NSMutableAttributedString()

        let paragraphFont = config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        let paragraphColor = config.paragraph.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: paragraphFont, color: paragraphColor)

        for child in root.children {
            // A synthetic paragraph gives bare plugin block nodes their
            // block margins and alignment.
            if rootBlockTypes.contains(child.type) {
                context.rendersPluginBlock = true
                let paragraph = MarkdownASTNode(type: .paragraph, children: [child])
                factory.renderer(for: .paragraph).render(node: paragraph, into: output, context: context)
                context.rendersPluginBlock = false
                continue
            }
            factory.renderer(for: child.type).render(node: child, into: output, context: context)
        }

        context.clearBlockStyle()
        BaselineShiftRenderer.applyShifts(to: output, config: config)
        return output
    }
}
