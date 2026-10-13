@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import com.swmansion.enriched.markdown.plugin.PluginRegistry

/**
 * RaTeX-backed LaTeX rendering for `$...$` and `$$...$$`. Enable it for a Compose subtree with a
 * scope:
 *
 * ```
 * LatexMathPlugin {
 *   EnrichedMarkdownText(markdown, flags = Md4cFlags(latexMath = true))
 * }
 * ```
 *
 * Without it core echoes the source of both node types, delimiters included; parsing them at all
 * still needs `Md4cFlags(latexMath = true)`.
 */
object LatexMathPlugin : MarkdownPlugin {
  const val ID = "com.swmansion.enriched.markdown.math"

  override val id: String = ID

  override fun install(registry: PluginRegistry) {
    registry.registerNodeRenderer(NodeType.LatexMathInline) { config, context -> MathInlineRenderer(config, context) }
    // Display math standing on its own line is promoted to a top-level node by the parser and
    // claimed below as a segment of its own. What still reaches a node renderer is genuinely
    // mid-line display math (`a $$x$$ b`), which belongs in the text flow like inline math.
    registry.registerNodeRenderer(NodeType.LatexMathDisplay) { config, context -> MathInlineRenderer(config, context) }

    registry.registerBlockSegment(NodeType.LatexMathDisplay, MathBlockSegment())
  }
}
