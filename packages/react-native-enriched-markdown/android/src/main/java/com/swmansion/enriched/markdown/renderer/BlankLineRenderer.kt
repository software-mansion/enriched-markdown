package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode

// Renders a run of consecutive blank lines emitted when preserveBlankLines is
// enabled. Each blank line in the source is drawn as one empty line, so the
// rendered text keeps the exact line count that was typed (e.g. in
// EnrichedMarkdownTextInput). Any extra vertical spacing comes from the
// surrounding paragraph style and is left to the caller to configure.
class BlankLineRenderer : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val count = node.getAttribute("count")?.toIntOrNull() ?: 0
    if (count <= 0) {
      return
    }

    builder.ensureNewline()
    builder.append("\n".repeat(count))
  }

  private fun SpannableStringBuilder.ensureNewline() {
    if (isNotEmpty() && this[length - 1] != '\n') {
      append('\n')
    }
  }
}
