import EnrichedMarkdown
import SwiftUI
import UIKit

/// Enables `$…$`/`$$…$$` parsing and claims the math node types with
/// RaTeX-backed rendering.
package struct LaTeXRenderPlugin: MarkdownRenderPlugin {
    /// VoiceOver label for a formula; `{latex}` is replaced by its source.
    /// The public entry points repeat the literal: a package-level constant
    /// cannot be used as a public default argument.
    package static let defaultAccessibilityLabel: String = "Math: {latex}"

    private let typeset: MathRenderer.Typeset
    private let accessibilityLabel: String

    package init(accessibilityLabel: String = LaTeXRenderPlugin.defaultAccessibilityLabel) {
        self.init(typeset: MathRenderer.raTeXTypeset, accessibilityLabel: accessibilityLabel)
    }

    /// Tests inject a deterministic typesetter.
    init(
        typeset: @escaping MathRenderer.Typeset,
        accessibilityLabel: String = LaTeXRenderPlugin.defaultAccessibilityLabel
    ) {
        self.typeset = typeset
        self.accessibilityLabel = accessibilityLabel
    }

    package func renderer(for type: NodeType, config: MarkdownStyleConfig) -> NodeRenderer? {
        switch type {
        case .latexMathInline, .latexMathDisplay:
            return MathRenderer(
                typeset: typeset,
                blockStyle: config.mathBlock,
                inlineStyle: config.inlineMath,
                accessibilityLabel: accessibilityLabel
            )
        default:
            return nil
        }
    }

    package func blockMargins(for type: NodeType, config: MarkdownStyleConfig) -> BlockMargins {
        BlockMargins(marginTop: config.mathBlock.marginTop, marginBottom: config.mathBlock.marginBottom)
    }

    package var defaultTheme: MarkdownTheme? { .latexDefault }

    package func adjustFlags(_ flags: inout Md4cFlags) {
        flags.latexMathEnabled = true
    }

    package var rootBlockNodeTypes: Set<NodeType> {
        [.latexMathDisplay]
    }
}

public extension View {
    /// Parses and renders LaTeX math (`$…$` inline, `$$…$$` display) with
    /// the bundled RaTeX engine, styled by `MarkdownTheme.latexDefault`
    /// underneath the themes applied around this view.
    ///
    /// `accessibilityLabel` is what VoiceOver speaks for a formula, with
    /// `{latex}` replaced by the source (the raw LaTeX is read verbatim; no
    /// speech conversion is attempted). The innermost modifier wins.
    func markdownLaTeX(accessibilityLabel: String = "Math: {latex}") -> some View {
        transformEnvironment(\.markdownRenderPlugins) { plugins in
            plugins.removeAll { $0 is LaTeXRenderPlugin }
            plugins.append(LaTeXRenderPlugin(accessibilityLabel: accessibilityLabel))
        }
    }
}

public extension MarkdownRenderer {
    /// `MarkdownRenderer.render` with RaTeX math typesetting installed.
    static func renderLaTeX(
        _ markdown: String,
        config: MarkdownStyleConfig,
        flags: Md4cFlags = .commonMark,
        imageRequestHeaders: [String: String] = [:],
        accessibilityLabel: String = "Math: {latex}"
    ) -> NSAttributedString {
        render(
            markdown,
            config: config,
            flags: flags,
            imageRequestHeaders: imageRequestHeaders,
            plugins: [LaTeXRenderPlugin(accessibilityLabel: accessibilityLabel)]
        )
    }
}
