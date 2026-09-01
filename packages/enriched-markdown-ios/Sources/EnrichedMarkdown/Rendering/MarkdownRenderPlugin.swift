import UIKit

/// Extension seam for optional sibling modules (EnrichedMarkdownLaTeX today).
/// Plugins are consulted before the built-in renderers.
package protocol MarkdownRenderPlugin {
    /// A renderer for `type`, or nil to leave it to the next plugin or the
    /// built-ins. Called once per node type per render; the result is cached.
    func renderer(for type: NodeType, config: MarkdownStyleConfig) -> NodeRenderer?

    /// Adjusts parser flags before parsing, e.g. enabling the md4c extension
    /// whose nodes the plugin renders.
    func adjustFlags(_ flags: inout Md4cFlags)

    /// Node types the parser emits bare at document root (promoted isolated
    /// display math, for instance) that should render wrapped in a synthetic
    /// paragraph; `RenderContext.rendersPluginBlock` is true while it renders.
    var rootBlockNodeTypes: Set<NodeType> { get }
}

package extension MarkdownRenderPlugin {
    func adjustFlags(_ flags: inout Md4cFlags) {}

    var rootBlockNodeTypes: Set<NodeType> { [] }
}

/// Adopted by plugin-created attachments so base components can handle them
/// without knowing their concrete types.
package protocol MarkdownPluginAttachment: NSTextAttachment {
    /// Source with markdown syntax restored, for Copy as Markdown.
    func markdownText() -> String
    /// Standalone block; wrapped in blank lines by Copy as Markdown.
    var isBlock: Bool { get }
    /// True exempts paragraphs containing the attachment from fixed
    /// line-height caps, so taller-than-text content is not clipped.
    var preservesNaturalLineHeight: Bool { get }
}

package extension MarkdownPluginAttachment {
    var preservesNaturalLineHeight: Bool { true }
}
