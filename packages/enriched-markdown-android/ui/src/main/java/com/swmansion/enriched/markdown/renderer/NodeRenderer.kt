@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.text.SpannableStringBuilder
import android.text.style.CharacterStyle
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
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
  val onPluginEvent: PluginEventSink? = null,
)

class RendererFactory internal constructor(
  private val config: RendererConfig,
  val context: Context,
  private val plugins: PluginSnapshot,
) {
  val blockStyleContext = BlockStyleContext()
  val styleCache = SpanStyleCache(config.style, context)

  private data class DeferredSpan(
    val span: CharacterStyle,
    val start: Int,
    val end: Int,
  )

  private val deferredSpans = mutableListOf<DeferredSpan>()

  fun registerDeferredSpan(
    span: CharacterStyle,
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

  private val builtInRenderers: Map<MarkdownASTNode.NodeType, NodeRenderer> by lazy {
    buildMap {
      put(MarkdownASTNode.NodeType.Document, DocumentRenderer())
      put(MarkdownASTNode.NodeType.Paragraph, ParagraphRenderer(config))
      put(MarkdownASTNode.NodeType.Heading, HeadingRenderer(config))
      put(MarkdownASTNode.NodeType.Blockquote, BlockquoteRenderer(config))
      // An admonition is a themed blockquote: same renderer, which reads the node type to decide
      // whether to reserve and paint a header.
      put(MarkdownASTNode.NodeType.Admonition, BlockquoteRenderer(config))
      put(MarkdownASTNode.NodeType.CodeBlock, CodeBlockRenderer(config))
      put(MarkdownASTNode.NodeType.UnorderedList, ListRenderer(config, isOrdered = false))
      put(MarkdownASTNode.NodeType.OrderedList, ListRenderer(config, isOrdered = true))
      put(MarkdownASTNode.NodeType.ListItem, ListItemRenderer(config))
      put(MarkdownASTNode.NodeType.Text, textRenderer)
      put(MarkdownASTNode.NodeType.Link, LinkRenderer(config))
      put(MarkdownASTNode.NodeType.Strong, StrongRenderer(config))
      put(MarkdownASTNode.NodeType.Emphasis, EmphasisRenderer(config))
      put(MarkdownASTNode.NodeType.Strikethrough, StrikethroughRenderer())
      put(MarkdownASTNode.NodeType.Underline, UnderlineRenderer())
      put(MarkdownASTNode.NodeType.Highlight, HighlightRenderer())
      put(MarkdownASTNode.NodeType.Code, CodeRenderer(config))
      put(MarkdownASTNode.NodeType.Image, ImageRenderer())
      put(MarkdownASTNode.NodeType.LineBreak, lineBreakRenderer)
      put(MarkdownASTNode.NodeType.SoftBreak, softBreakRenderer)
      put(MarkdownASTNode.NodeType.ThematicBreak, ThematicBreakRenderer(config))
      put(MarkdownASTNode.NodeType.BlankLine, BlankLineRenderer(config))
      put(MarkdownASTNode.NodeType.Superscript, SuperscriptRenderer())
      put(MarkdownASTNode.NodeType.Subscript, SubscriptRenderer())
      // Core knows the delimiters - they are parser syntax - but not how to draw an equation,
      // so without a math plugin these echo their own source.
      put(MarkdownASTNode.NodeType.LatexMathInline, LatexSourceRenderer(isDisplay = false))
      put(MarkdownASTNode.NodeType.LatexMathDisplay, LatexSourceRenderer(isDisplay = true))
      put(MarkdownASTNode.NodeType.Spoiler, SpoilerRenderer())
    }
  }

  // Plugins layered over core's own, so a plugin that claims a node type replaces core's handling.
  private val renderers: Map<MarkdownASTNode.NodeType, NodeRenderer> by lazy {
    if (plugins.nodeRenderers.isEmpty()) return@lazy builtInRenderers
    builtInRenderers + plugins.nodeRenderers.mapValues { (_, rendererFactory) -> rendererFactory(config, context) }
  }

  /** Core's renderer for [type], ignoring plugins; lets a plugin hand back a node it declines. */
  @InternalPluginApi
  fun builtInRenderer(type: MarkdownASTNode.NodeType): NodeRenderer? = builtInRenderers[type]

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
    renderNodes(node.children, builder, onLinkPress, onLinkLongPress)
  }

  /**
   * Renders a flat list of sibling nodes in order, dispatching each to its
   * NodeRenderer. Lets a caller render a segment's own top-level nodes directly,
   * without wrapping them in a synthetic Document node.
   */
  fun renderNodes(
    nodes: List<MarkdownASTNode>,
    builder: SpannableStringBuilder,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
  ) {
    nodes.forEach { node -> getRenderer(node).render(node, builder, onLinkPress, onLinkLongPress, this) }
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
