package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.SpannableString
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.styles.StyleConfig

class Renderer {
  private var cachedFactory: RendererFactory? = null
  private var cachedStyle: StyleConfig? = null
  private var cachedContext: Context? = null
  private var cachedImageRequestHeaders: Map<String, String> = emptyMap()

  private val collectedImageSpans = mutableListOf<ImageSpan>()
  private var lastElementMarginBottom: Float = 0f

  fun configure(
    style: StyleConfig,
    context: Context,
    imageRequestHeaders: Map<String, String> = emptyMap(),
  ) {
    if (cachedStyle === style && cachedContext === context && cachedImageRequestHeaders == imageRequestHeaders) return

    cachedStyle = style
    cachedContext = context
    cachedImageRequestHeaders = imageRequestHeaders
    cachedFactory =
      RendererFactory(
        RendererConfig(style, imageRequestHeaders),
        context,
      ) { span -> reportImageSpan(span) }
  }

  fun renderDocument(
    document: MarkdownASTNode,
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
  ): SpannableString {
    val factory =
      requireNotNull(cachedFactory) {
        "Renderer must be configured with a style before calling renderDocument."
      }

    factory.resetForNewRender()
    collectedImageSpans.clear()
    lastElementMarginBottom = 0f

    val builder = SpannableStringBuilder()

    renderNode(document, builder, onLinkPress, onLinkLongPress, factory)

    // Remove trailing margin from last block element
    removeTrailingMargin(builder)

    // Flush deferred spans (e.g. BaselineShiftSpan) after all block-level spans are set.
    // See BaselineShiftRenderer for context and the proper long-term fix.
    factory.flushDeferredSpans(builder)

    return SpannableString(builder)
  }

  /** Removes trailing newlines and captures the margin of the final element. */
  private fun removeTrailingMargin(builder: SpannableStringBuilder) {
    if (builder.isEmpty()) return

    // Identify the last margin span and store its value
    val lastSpan =
      builder
        .getSpans(0, builder.length, MarginBottomSpan::class.java)
        .maxByOrNull { builder.getSpanEnd(it) }

    lastElementMarginBottom = lastSpan?.marginBottom ?: 0f

    // Trim trailing newlines
    while (builder.endsWith('\n')) {
      builder.delete(builder.length - 1, builder.length)
    }

    // Clean up the span if it no longer covers any text
    if (lastSpan != null && builder.getSpanEnd(lastSpan) >= builder.length) {
      builder.removeSpan(lastSpan)
    }
  }

  /**
   * Returns the marginBottom value of the last element in the document.
   * This is dynamically determined from the actual last element (paragraph, image, heading, etc.)
   * and can be used in MeasurementStore to adjust the measured height.
   */
  fun getLastElementMarginBottom(): Float = lastElementMarginBottom

  private fun renderNode(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  ) {
    factory.getRenderer(node).render(node, builder, onLinkPress, onLinkLongPress, factory)
  }

  /**
   * Internal helper used by the Factory's lambda to collect spans.
   */
  private fun reportImageSpan(span: ImageSpan) {
    collectedImageSpans.add(span)
  }

  /**
   * Provides the EnrichedMarkdownText with the exact list of spans that need registration.
   */
  fun getCollectedImageSpans(): List<ImageSpan> = collectedImageSpans
}
