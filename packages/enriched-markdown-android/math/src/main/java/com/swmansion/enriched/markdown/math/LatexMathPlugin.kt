@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import com.swmansion.enriched.markdown.plugin.PluginRegistry

/**
 * RaTeX-backed LaTeX rendering for `$...$` and `$$...$$`. Enable it for a Compose subtree with a
 * scope:
 *
 * ```
 * LatexMathPlugin {
 *   EnrichedMarkdownText(markdown)
 * }
 * ```
 *
 * Enabling it is also what makes the parser recognise math.
 */
open class LatexMathPlugin(
  private val accessibilityLabel: MathAccessibilityLabel,
) : MarkdownPlugin {
  constructor(
    accessibilityLabel: String = MathAccessibilityLabel.DEFAULT_TEMPLATE,
  ) : this(MathAccessibilityLabel.template(accessibilityLabel))

  override val id: String = ID

  override fun install(registry: PluginRegistry) {
    registry.registerNodeRenderer(NodeType.LatexMathInline) { config, context -> MathInlineRenderer(config, context, accessibilityLabel) }
    // Display math standing on its own line is promoted to a top-level node by the parser and
    // claimed below as a segment of its own. What still reaches a node renderer is genuinely
    // mid-line display math (`a $$x$$ b`), which belongs in the text flow like inline math.
    registry.registerNodeRenderer(NodeType.LatexMathDisplay) { config, context -> MathInlineRenderer(config, context, accessibilityLabel) }

    registry.registerBlockSegment(NodeType.LatexMathDisplay, MathBlockSegment(accessibilityLabel))
  }

  override fun adjustParserFlags(flags: Md4cFlags): Md4cFlags = flags.copy(latexMath = true)

  override fun equals(other: Any?): Boolean = other is LatexMathPlugin && other.accessibilityLabel == accessibilityLabel

  override fun hashCode(): Int = accessibilityLabel.hashCode()

  companion object Default : LatexMathPlugin() {
    const val ID = "com.swmansion.enriched.markdown.math"
  }
}
