package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.math.LatexErrorReporter
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.styles.StyleConfig

class Renderer {
  private var cachedFactory: RendererFactory? = null
  private var cachedStyle: StyleConfig? = null
  private var cachedContext: Context? = null
  private var cachedOnLatexError: LatexErrorReporter? = null

  private val collectedImageSpans = mutableListOf<ImageSpan>()
  private var lastElementMarginBottom: Float = 0f
  private var blockStarts = IntArray(0)
  private var blockTaskStarts = IntArray(0)

  fun configure(
    style: StyleConfig,
    context: Context,
    onLatexError: LatexErrorReporter? = null,
  ) {
    if (cachedStyle === style && cachedContext === context && cachedOnLatexError === onLatexError) return

    cachedStyle = style
    cachedContext = context
    cachedOnLatexError = onLatexError
    cachedFactory =
      RendererFactory(
        RendererConfig(style, onLatexError),
        context,
      ) { span -> reportImageSpan(span) }
  }

  fun renderDocument(
    document: MarkdownASTNode,
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
  ): SpannableStringBuilder = renderContent(document.children, onLinkPress, onLinkLongPress)

  /**
   * Renders a flat list of sibling nodes into a fresh buffer and hands over
   * ownership of it. This is the generic envelope shared by the document and
   * block-segment paths: reset the factory, build the spannable, trim the trailing
   * margin, and flush deferred spans (e.g. BaselineShiftSpan) after all block-level
   * spans are set - see BaselineShiftRenderer for the proper long-term fix.
   *
   * An optional [block] decorates the pass - it enters a block style before the
   * nodes render and post-processes the finished builder - letting a caller render
   * content as e.g. blockquote text without this class knowing anything
   * block-specific. See [BlockquoteTextRenderer].
   *
   * Task-list items are numbered from [startingTaskIndex], so a caller rendering a
   * document in several passes keeps their indices document-global.
   *
   * The builder is returned as-is rather than frozen into a `SpannableString`:
   * the markdown text view adopts it verbatim (see `NoCopySpannableFactory`),
   * and converting it would cost a quadratic span copy for no benefit. Each call
   * builds its own buffer, so callers must not mutate one they have passed on.
   */
  fun renderContent(
    nodes: List<MarkdownASTNode>,
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
    block: BlockquoteTextRenderer? = null,
    startingTaskIndex: Int = 0,
  ): SpannableStringBuilder {
    val factory =
      requireNotNull(cachedFactory) {
        "Renderer must be configured with a style before rendering."
      }

    factory.resetForNewRender()
    // Must run after resetForNewRender, which zeroes taskItemCount.
    factory.blockStyleContext.taskItemCount = startingTaskIndex
    collectedImageSpans.clear()
    lastElementMarginBottom = 0f

    val builder = SpannableStringBuilder()

    blockStarts = IntArray(nodes.size)
    blockTaskStarts = IntArray(nodes.size)
    block?.push(factory.blockStyleContext)
    try {
      for ((index, node) in nodes.withIndex()) {
        blockStarts[index] = builder.length
        blockTaskStarts[index] = factory.blockStyleContext.taskItemCount
        factory.renderNode(node, builder, onLinkPress, onLinkLongPress)
      }
    } finally {
      block?.pop(factory.blockStyleContext)
    }

    removeTrailingMargin(builder)
    block?.postProcess(builder)
    factory.flushDeferredSpans(builder)

    return builder
  }

  /** Task-list items rendered by the last [renderContent], continuing from its `startingTaskIndex`. */
  fun getTaskItemCount(): Int = cachedFactory?.blockStyleContext?.taskItemCount ?: 0

  /**
   * Where each top-level node of the last [renderContent] starts in its buffer, and the task
   * count before it. Rendering resumes at any of them: between top-level nodes the context is
   * back at its baseline, and the buffer is empty or ends in "\n", which renderers treat alike.
   * So rendering the nodes from one on gives that part of the buffer, as long as every top-level
   * node renders nothing or ends in "\n" (TextRenderCacheTest covers each kind).
   */
  fun getBlockStarts(): IntArray = blockStarts

  fun getBlockTaskStarts(): IntArray = blockTaskStarts

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
