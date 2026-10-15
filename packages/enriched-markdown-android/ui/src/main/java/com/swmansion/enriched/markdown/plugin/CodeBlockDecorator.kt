package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * Adds spans to a code block core has already rendered, e.g. syntax-highlighting colors. Runs on
 * the render thread, once per code block, top-level or nested.
 *
 * The code is `builder.subSequence(start, end)`: what the block displays, read back from the
 * builder rather than the AST. A nested block's own spans are set by then, so a character style
 * set here applies after the block's and is not repainted with its text color. Enclosing
 * blockquote and list item spans take a higher priority, so they apply before both. A top-level
 * block is a view of its own, so its builder holds only its code, with no block span.
 *
 * Decorators run only from core's code block rendering. A plugin that claims [NodeType.CodeBlock],
 * with a node renderer or a block segment, replaces that rendering for the blocks it takes, and no
 * decorator runs on them.
 */
@InternalPluginApi
fun interface CodeBlockDecorator {
  /**
   * [language] is the fence's info string language, or null when it has none. The block's colors
   * are in [StyleConfig.codeBlockStyle]; a plugin's own style is in [StyleConfig.extensions].
   */
  fun decorate(
    builder: SpannableStringBuilder,
    start: Int,
    end: Int,
    language: String?,
    style: StyleConfig,
    context: Context,
  )
}
