package com.swmansion.enriched.markdown.renderer

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.SpoilerSpan

class SpoilerRenderer : NodeRenderer {
  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    factory.renderWithSpan(builder, { factory.renderChildren(node, builder, onLinkPress, onLinkLongPress) }) { start, end, blockStyle ->
      // Deferred so the span runs after every wrapper and block span that sets a text color;
      // any of those would otherwise make the concealed text visible again.
      factory.registerDeferredSpan(SpoilerSpan(factory.styleCache, blockStyle), start, end)
    }
  }
}
