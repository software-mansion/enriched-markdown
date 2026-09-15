package com.swmansion.enriched.markdown.renderer

import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.LineHeightSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.AdmonitionHeaderSpan
import com.swmansion.enriched.markdown.spans.BlockquoteSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_CONTAINER_BACKGROUND
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.span.applyMarginBottom
import com.swmansion.enriched.markdown.utils.text.span.applyMarginTop
import com.swmansion.enriched.markdown.utils.text.span.createLineHeightSpan

class BlockquoteRenderer(
  private val config: RendererConfig,
) : NodeRenderer {
  private companion object {
    /** md4c always reports a type, but an empty attribute reads as a plain "note" alert. */
    const val DEFAULT_ADMONITION_TYPE = "note"
  }

  override fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    val start = builder.length
    val style = config.style.blockquoteStyle
    val context = factory.blockStyleContext
    val depth = context.blockquoteDepth

    // An admonition nested in a list deliberately falls back to plain blockquote rendering with no
    // header — the same limitation both React Native renderers carry, kept here so the three
    // platforms agree rather than diverge.
    val admonitionType =
      if (node.type == MarkdownASTNode.NodeType.Admonition && context.listDepth == 0) {
        node.getAttribute("admonitionType")?.takeIf { it.isNotEmpty() } ?: DEFAULT_ADMONITION_TYPE
      } else {
        null
      }

    // Track depth to handle nested indentation levels
    context.blockquoteDepth = depth + 1
    context.setBlockquoteStyle(style)

    try {
      factory.renderChildren(node, builder, onLinkPress, onLinkLongPress)
    } finally {
      context.popBlockStyle()
      context.blockquoteDepth = depth
    }

    // A body-less quote renders nothing, admonition or not: its header would consist only of the
    // spacer line, which Renderer.removeTrailingMargin trims away as a trailing newline anyway.
    if (builder.length == start) return
    var end = builder.length
    val padding = style.padding.toInt()

    var contentStart = start
    if (padding > 0) {
      builder.insert(start, "\n")
      builder.setSpan(
        BlockquotePaddingSpacerSpan(padding),
        start,
        start + 1,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
      contentStart = start + 1
      end += 1
    }

    // The header sits below the quote's top padding and above the body, on a spacer line of its
    // own; BlockquoteSpan paints into the band this reserves. See AdmonitionHeaderSpan for why the
    // header cannot simply grow the first content line.
    val headerSpan = admonitionType?.let { AdmonitionHeaderSpan(it, style) }
    if (headerSpan != null) {
      builder.insert(contentStart, "\n")
      builder.setSpan(
        headerSpan,
        contentStart,
        contentStart + 1,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
      contentStart += 1
      end += 1
    }

    // Find immediately nested quotes to exclude them from this level's line-height/margins
    val nestedRanges =
      builder
        .getSpans(contentStart, end, BlockquoteSpan::class.java)
        .filter { it.depth == depth + 1 }
        .map { builder.getSpanStart(it) to builder.getSpanEnd(it) }
        .sortedBy { it.first }

    // The accent bar / background span covers the full box, incl. the top spacer and the header.
    builder.setSpan(
      BlockquoteSpan(style, depth, factory.context, factory.styleCache, headerSpan),
      start,
      end,
      SPAN_FLAGS_CONTAINER_BACKGROUND,
    )

    applySpansExcludingNested(builder, nestedRanges, contentStart, end, createLineHeightSpan(style.lineHeight))

    if (padding > 0) {
      builder.setSpan(
        BlockquoteBoundaryPaddingSpan(padding),
        contentStart,
        end,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }

    // Margins are only applied by the outermost (root) quote
    if (depth == 0) {
      applyMarginTop(builder, start, style.marginTop)
      applyMarginBottom(builder, style.marginBottom)
    }
  }

  /**
   * A blockquote's top padding, rendered as a standalone spacer line of exactly
   * [padding] px.
   *
   * Top padding cannot be added by growing the first content line's ascent:
   * StaticLayout reuses one FontMetricsInt across a paragraph's soft-wrapped lines,
   * so the inflated first-line metrics leak into the wrapped continuation line, where
   * the line-height clamp then skews them into overlapping baselines. A spacer sits in
   * its own paragraph, and setting absolute metrics keeps it fixed regardless of that
   * reuse.
   */
  private class BlockquotePaddingSpacerSpan(
    private val padding: Int,
  ) : LineHeightSpan {
    override fun chooseHeight(
      text: CharSequence,
      startLine: Int,
      endLine: Int,
      spanstartv: Int,
      v: Int,
      fm: Paint.FontMetricsInt,
    ) {
      fm.top = 0
      fm.ascent = 0
      fm.descent = padding
      fm.bottom = padding
    }
  }

  /**
   * A blockquote's bottom padding, grown onto the last content line's descent (safe
   * because no later line inherits its metrics; top padding uses
   * [BlockquotePaddingSpacerSpan]).
   *
   * The span range can include trailing '\n'(s) that form no visible line, so the last
   * drawn line ends before getSpanEnd; the comparison uses the visible content end.
   */
  private class BlockquoteBoundaryPaddingSpan(
    private val padding: Int,
  ) : LineHeightSpan {
    override fun chooseHeight(
      text: CharSequence,
      startLine: Int,
      endLine: Int,
      spanstartv: Int,
      v: Int,
      fm: Paint.FontMetricsInt,
    ) {
      if (text !is Spanned) return

      var contentEnd = text.getSpanEnd(this)
      while (contentEnd > 0 && text[contentEnd - 1] == '\n') {
        contentEnd--
      }
      if (endLine >= contentEnd) {
        fm.descent += padding
        fm.bottom += padding
      }
    }
  }

  private fun applySpansExcludingNested(
    builder: SpannableStringBuilder,
    nestedRanges: List<Pair<Int, Int>>,
    start: Int,
    end: Int,
    span: Any,
  ) {
    var currentPos = start
    for ((nestedStart, nestedEnd) in nestedRanges) {
      if (currentPos < nestedStart) {
        builder.setSpan(span, currentPos, nestedStart, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
      }
      currentPos = nestedEnd
    }
    if (currentPos < end) {
      builder.setSpan(span, currentPos, end, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
  }
}
