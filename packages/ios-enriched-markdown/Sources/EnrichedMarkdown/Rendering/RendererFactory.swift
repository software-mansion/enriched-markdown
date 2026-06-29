import UIKit

final class RendererFactory {
    private let config: MarkdownStyleConfig
    private var cache: [NodeType: NodeRenderer] = [:]
    private lazy var childrenOnlyRenderer = ChildrenOnlyRenderer(factory: self)

    init(config: MarkdownStyleConfig) {
        self.config = config
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
        switch type {
        case .text:
            return TextRenderer()
        case .paragraph:
            return ParagraphRenderer(factory: self, config: config)
        case .strong:
            return StrongRenderer(factory: self, config: config)
        case .emphasis:
            return EmphasisRenderer(factory: self, config: config)
        default:
            return childrenOnlyRenderer
        }
    }
}
