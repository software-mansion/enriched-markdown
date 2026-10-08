@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.text.Spannable
import android.view.View
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginBlockSegment
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSegmentPayload
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.StyleConfig

sealed interface RenderedSegment {
  val signature: Long

  data class Text(
    /**
     * The renderer's own buffer, which the segment's text view adopts uncopied.
     * Once displayed it *is* the view's live text, so the view mutates it: `TextView`
     * attaches its `ChangeWatcher`, the `Editor` its `SpanController`, and selection
     * adds and moves the selection marks — all as spans on this very instance.
     *
     * A segment is therefore only a faithful record of what the renderer produced
     * until the view takes it. Anything that caches, diffs, counts or hashes the spans
     * here must read them before the segment is applied, or filter the view's spans
     * out; reading afterwards yields the view's bookkeeping mixed in with the markdown
     * spans, and a result that changes as the user merely selects text.
     */
    val styledText: Spannable,
    val imageSpans: List<ImageSpan>,
    val needsJustify: Boolean,
    val lastElementMarginBottom: Float,
    override val signature: Long,
  ) : RenderedSegment

  data class Table(
    val node: MarkdownASTNode,
    override val signature: Long,
    val imageRequestHeaders: Map<String, String> = emptyMap(),
    val plugins: PluginSnapshot = PluginSnapshot.EMPTY,
  ) : RenderedSegment

  /** Holds the plugin that produced [payload], so its view is built by that same plugin. */
  data class Custom<P : PluginSegmentPayload>(
    val pluginId: String,
    val plugin: PluginBlockSegment<P>,
    val payload: P,
    override val signature: Long,
  ) : RenderedSegment {
    fun createView(config: SegmentViewConfig): View = plugin.createView(payload, config)

    fun updateView(
      view: View,
      config: SegmentViewConfig,
    ) = plugin.updateView(view, payload, config)

    fun matchesView(view: View): Boolean = plugin.matchesView(view)
  }
}

object MarkdownSegmentRenderer {
  /** [plugins] must be the snapshot [segments] were split with. */
  fun render(
    segments: List<MarkdownSegment>,
    style: StyleConfig,
    context: Context,
    imageRequestHeaders: Map<String, String> = emptyMap(),
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
    onPluginEvent: PluginEventSink? = null,
    plugins: PluginSnapshot = PluginSnapshot.EMPTY,
  ): List<RenderedSegment> {
    // Task indices must stay document-global: each Text segment gets a fresh Renderer,
    // so the running count is threaded through explicitly rather than reset per segment.
    var taskIndexOffset = 0

    fun renderAsText(nodes: List<MarkdownASTNode>): RenderedSegment.Text {
      val (rendered, taskItemCount) =
        renderTextSegment(
          nodes,
          style,
          context,
          imageRequestHeaders,
          onLinkPress,
          onLinkLongPress,
          onPluginEvent,
          plugins,
          taskIndexOffset,
        )
      taskIndexOffset = taskItemCount
      return rendered
    }

    return segments.map { segment ->
      when (segment) {
        is MarkdownSegment.Text -> {
          renderAsText(segment.nodes)
        }

        is MarkdownSegment.Table -> {
          val signature = SegmentSignature.signatureForNode(segment.node) xor SegmentSignature.TABLE_KIND_SALT
          RenderedSegment.Table(segment.node, signature, imageRequestHeaders, plugins)
        }

        is MarkdownSegment.Custom -> {
          // A null payload is the plugin declining this node - half-arrived content, say. Its
          // source still has to reach the screen, so it falls back to core text rendering.
          renderCustom(segment.pluginId, segment.plugin, segment.node, style, context, onPluginEvent)
            ?: renderAsText(listOf(segment.node))
        }
      }
    }
  }

  private fun <P : PluginSegmentPayload> renderCustom(
    pluginId: String,
    plugin: PluginBlockSegment<P>,
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
    onPluginEvent: PluginEventSink?,
  ): RenderedSegment.Custom<P>? {
    val payload = plugin.renderPayload(node, style, context, onPluginEvent) ?: return null
    return RenderedSegment.Custom(
      pluginId = pluginId,
      plugin = plugin,
      payload = payload,
      signature = SegmentSignature.signatureForPluginSegment(pluginId, payload.signatureSource),
    )
  }

  private fun renderTextSegment(
    nodes: List<MarkdownASTNode>,
    style: StyleConfig,
    context: Context,
    imageRequestHeaders: Map<String, String>,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    onPluginEvent: PluginEventSink?,
    plugins: PluginSnapshot,
    startingTaskIndex: Int,
  ): Pair<RenderedSegment.Text, Int> {
    val renderer = Renderer().apply { configure(style, context, imageRequestHeaders, onPluginEvent, plugins) }
    val signature = SegmentSignature.signatureForNodes(nodes) xor SegmentSignature.TEXT_KIND_SALT

    val styledText = renderer.renderContent(nodes, onLinkPress, onLinkLongPress, startingTaskIndex)

    val rendered =
      RenderedSegment.Text(
        styledText = styledText,
        imageSpans = renderer.getCollectedImageSpans().toList(),
        needsJustify = style.needsJustify,
        lastElementMarginBottom = renderer.getLastElementMarginBottom(),
        signature = signature,
      )

    return rendered to renderer.getTaskItemCount()
  }
}
