package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode

/**
 * Plain-text rendering for table nodes that never become a TableContainerView.
 *
 * Only a root-level table is split into its own view segment; one nested in a blockquote or a list
 * item stays inside the text segment and reaches the renderer instead. Without these the structural
 * table nodes would fall through to the text renderer, which reads only a node's own content and
 * does not recurse, silently dropping every cell.
 */
class TableSectionRenderer : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
  }
}

class TableRowRenderer : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val start = builder.length
    factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    if (builder.length > start) builder.append('\n')
  }
}

class TableCellRenderer : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val start = builder.length
    factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    if (builder.length > start) builder.append(' ')
  }
}
