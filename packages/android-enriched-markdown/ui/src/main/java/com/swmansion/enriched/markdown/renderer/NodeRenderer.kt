package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.SpannableStringBuilder
import android.text.style.MetricAffectingSpan
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.StyleConfig

interface NodeRenderer {
  fun render(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    factory: RendererFactory,
  )
}

data class RendererConfig(
  val style: StyleConfig,
  val imageRequestHeaders: Map<String, String> = emptyMap(),
)

class RendererFactory(
  private val config: RendererConfig,
  val context: Context,
  private val onImageSpanCreated: (ImageSpan) -> Unit,
) {
  val blockStyleContext = BlockStyleContext()
  val styleCache = SpanStyleCache(config.style, context)

  private data class DeferredSpan(
    val span: MetricAffectingSpan,
    val start: Int,
    val end: Int,
  )

  private val deferredSpans = mutableListOf<DeferredSpan>()

  fun registerDeferredSpan(
    span: MetricAffectingSpan,
    start: Int,
    end: Int,
  ) {
    deferredSpans.add(DeferredSpan(span, start, end))
  }

  fun flushDeferredSpans(builder: SpannableStringBuilder) {
    for ((span, start, end) in deferredSpans) {
      builder.setSpan(span, start, end, com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }
    deferredSpans.clear()
  }

  fun resetForNewRender() {
    blockStyleContext.resetForNewRender()
    deferredSpans.clear()
  }

  fun createImageSpan(
    imageUrl: String,
    isInline: Boolean,
    altText: String,
  ): ImageSpan =
    ImageSpan(
      context = context,
      imageUrl = imageUrl,
      styleConfig = config.style,
      isInline = isInline,
      altText = altText,
      requestHeaders = config.imageRequestHeaders,
    )

  private val textRenderer = TextRenderer()
  private val lineBreakRenderer = LineBreakRenderer()
  private val softBreakRenderer = SoftBreakRenderer()

  private val renderers: Map<MarkdownASTNode.NodeType, NodeRenderer> by lazy {
    buildMap {
      put(MarkdownASTNode.NodeType.Document, DocumentRenderer())
      put(MarkdownASTNode.NodeType.Paragraph, ParagraphRenderer(config))
      put(MarkdownASTNode.NodeType.Heading, HeadingRenderer(config))
      put(MarkdownASTNode.NodeType.Blockquote, BlockquoteRenderer(config))
      put(MarkdownASTNode.NodeType.CodeBlock, CodeBlockRenderer(config))
      put(MarkdownASTNode.NodeType.UnorderedList, ListRenderer(config, isOrdered = false))
      put(MarkdownASTNode.NodeType.OrderedList, ListRenderer(config, isOrdered = true))
      put(MarkdownASTNode.NodeType.ListItem, ListItemRenderer(config))
      put(MarkdownASTNode.NodeType.Text, textRenderer)
      put(MarkdownASTNode.NodeType.Link, LinkRenderer(config))
      put(MarkdownASTNode.NodeType.Strong, StrongRenderer(config))
      put(MarkdownASTNode.NodeType.Emphasis, EmphasisRenderer(config))
      put(MarkdownASTNode.NodeType.Code, CodeRenderer(config))
      put(MarkdownASTNode.NodeType.Image, ImageRenderer())
      put(MarkdownASTNode.NodeType.LineBreak, lineBreakRenderer)
      put(MarkdownASTNode.NodeType.SoftBreak, softBreakRenderer)
      put(MarkdownASTNode.NodeType.ThematicBreak, ThematicBreakRenderer(config))
    }
  }

  fun registerImageSpan(span: ImageSpan) {
    onImageSpanCreated(span)
  }

  fun getRenderer(node: MarkdownASTNode): NodeRenderer =
    renderers[node.type] ?: run {
      android.util.Log.w("RendererFactory", "No renderer for: ${node.type}")
      textRenderer
    }

  fun renderChildren(
    node: MarkdownASTNode,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
  ) {
    node.children.forEach { child ->
      getRenderer(child).render(child, builder, onLinkPress, onLinkLongPress, this)
    }
  }

  inline fun renderWithSpan(
    builder: SpannableStringBuilder,
    renderContent: () -> Unit,
    applySpan: (start: Int, end: Int, blockStyle: BlockStyle) -> Unit,
  ) {
    val start = builder.length
    renderContent()
    val end = builder.length

    if (end > start) {
      val blockStyle = blockStyleContext.requireBlockStyle()
      applySpan(start, end, blockStyle)
    }
  }
}
