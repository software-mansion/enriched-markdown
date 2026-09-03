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
    /// The text the parser's text nodes carry for the attachment's source
    /// range, so a verbatim copy slice can be validated against it.
    var literalText: String { get }
    /// Syntax immediately outside the tagged source range (a block delimiter
    /// may sit on its own line), consumed when a copy slice ends on the
    /// attachment; nil when there is none.
    var sourceDelimiters: (opening: String, closing: String)? { get }
}

package extension MarkdownPluginAttachment {
    var sourceDelimiters: (opening: String, closing: String)? { nil }
}
