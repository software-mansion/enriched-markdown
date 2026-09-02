import UIKit

final class AttributedRenderer {
    private let config: MarkdownStyleConfig
    private let factory: RendererFactory

    init(config: MarkdownStyleConfig, imageRequestHeaders: [String: String] = [:]) {
        self.config = config
        self.factory = RendererFactory(config: config, imageRequestHeaders: imageRequestHeaders)
    }

    func renderRoot(_ root: MarkdownASTNode) -> NSMutableAttributedString {
        let context = RenderContext()
        let output = NSMutableAttributedString()

        let paragraphFont = config.paragraph.font ?? UIFont.preferredFont(forTextStyle: .body)
        let paragraphColor = config.paragraph.foregroundColor ?? UIColor.label
        context.setBlockStyle(font: paragraphFont, color: paragraphColor)

        for child in root.children {
            factory.renderer(for: child.type).render(node: child, into: output, context: context)
        }

        context.clearBlockStyle()
        BaselineShiftRenderer.applyShifts(to: output, config: config)
        return output
    }
}
