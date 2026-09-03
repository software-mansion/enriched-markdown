import EnrichedMarkdown
import SwiftUI
import UIKit

/// Enables `$…$`/`$$…$$` parsing and claims the math node types with
/// RaTeX-backed rendering.
package struct LaTeXRenderPlugin: MarkdownRenderPlugin {
    private let typeset: MathRenderer.Typeset

    package init() {
        self.init(typeset: MathRenderer.raTeXTypeset)
    }

    /// Tests inject a deterministic typesetter.
    init(typeset: @escaping MathRenderer.Typeset) {
        self.typeset = typeset
    }

    package func renderer(for type: NodeType, config: MarkdownStyleConfig) -> NodeRenderer? {
        switch type {
        case .latexMathInline, .latexMathDisplay:
            return MathRenderer(typeset: typeset)
        default:
            return nil
        }
    }

    package func adjustFlags(_ flags: inout Md4cFlags) {
        flags.latexMathEnabled = true
    }

    package var rootBlockNodeTypes: Set<NodeType> {
        [.latexMathDisplay]
    }
}

public extension View {
    /// Parses and renders LaTeX math (`$…$` inline, `$$…$$` display) with
    /// the bundled RaTeX engine.
    func markdownLaTeX() -> some View {
        transformEnvironment(\.markdownRenderPlugins) { plugins in
            guard !plugins.contains(where: { $0 is LaTeXRenderPlugin }) else { return }
            plugins.append(LaTeXRenderPlugin())
        }
    }
}

public extension MarkdownRenderer {
    /// `MarkdownRenderer.render` with RaTeX math typesetting installed.
    static func renderLaTeX(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:]
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            flags: flags,
            imageRequestHeaders: imageRequestHeaders,
            plugins: [LaTeXRenderPlugin()]
        )
    }
}
