import UIKit

final class RendererFactory {
    private let config: MarkdownStyleConfig
    private let imageRequestHeaders: [String: String]
    private let plugins: [any MarkdownRenderPlugin]
    private var cache: [NodeType: NodeRenderer] = [:]
    private lazy var childrenOnlyRenderer = ChildrenOnlyRenderer(factory: self)

    init(
        config: MarkdownStyleConfig,
        imageRequestHeaders: [String: String] = [:],
        plugins: [any MarkdownRenderPlugin] = []
    ) {
        self.config = config
        self.imageRequestHeaders = imageRequestHeaders
        self.plugins = plugins
    }

    func renderer(for type: NodeType) -> NodeRenderer {
        if let cached = cache[type] {
            return cached
        }

        let renderer = createRenderer(for: type)
        cache[type] = renderer
        return renderer
    }

    func renderChildren(
        of node: MarkdownASTNode,
        into output: NSMutableAttributedString,
        context: RenderContext
    ) {
        for child in node.children {
            renderer(for: child.type).render(node: child, into: output, context: context)
        }
    }

    private func createRenderer(for type: NodeType) -> NodeRenderer {
        for plugin in plugins {
            if let renderer = plugin.renderer(for: type, config: config) {
                return renderer
            }
        }
        if let renderer = createInlineRenderer(for: type) {
            return renderer
        }
        if let renderer = createBlockRenderer(for: type) {
            return renderer
        }
        #if DEBUG
        print("[EnrichedMarkdown] No renderer for node type '\(type)'; rendering its children only.")
        #endif
        return childrenOnlyRenderer
    }

    private func createInlineRenderer(for type: NodeType) -> NodeRenderer? {
        switch type {
        case .text:
            return TextRenderer()
        case .strong:
            return StrongRenderer(factory: self, config: config)
        case .emphasis:
            return EmphasisRenderer(factory: self, config: config)
        case .strikethrough:
            return StrikethroughRenderer(factory: self, config: config)
        case .underline:
            return UnderlineRenderer(factory: self, config: config)
        case .superscript:
            return BaselineShiftRenderer(factory: self, attributeKey: MarkdownAttribute.superscript)
        case .subscript:
            return BaselineShiftRenderer(factory: self, attributeKey: MarkdownAttribute.subscript)
        case .link:
            return LinkRenderer(factory: self, config: config)
        case .lineBreak:
            return LineBreakRenderer()
        case .softBreak:
            return SoftBreakRenderer()
        case .code:
            return CodeRenderer(factory: self, config: config)
        case .image:
            return ImageRenderer(config: config, requestHeaders: imageRequestHeaders)
        default:
            return nil
        }
    }

    private func createBlockRenderer(for type: NodeType) -> NodeRenderer? {
        switch type {
        case .paragraph:
            return ParagraphRenderer(factory: self, config: config)
        case .heading:
            return HeadingRenderer(factory: self, config: config)
        case .thematicBreak:
            return ThematicBreakRenderer(config: config)
        case .blankLine:
            return BlankLineRenderer(config: config)
        case .codeBlock:
            return CodeBlockRenderer(factory: self, config: config)
        case .blockquote:
            return BlockquoteRenderer(factory: self, config: config)
        case .unorderedList:
            return ListRenderer(factory: self, config: config, isOrdered: false)
        case .orderedList:
            return ListRenderer(factory: self, config: config, isOrdered: true)
        case .listItem:
            return ListItemRenderer(factory: self, config: config)
        case .table:
            return TableRenderer(factory: self, config: config)
        default:
            return nil
        }
    }
}
