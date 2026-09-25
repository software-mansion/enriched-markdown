@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.text.Spannable
import android.util.Log
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSegmentPayload
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
  ) : RenderedSegment

  data class Custom(
    val pluginId: String,
    val payload: PluginSegmentPayload,
    override val signature: Long,
  ) : RenderedSegment
}

object MarkdownSegmentRenderer {
  private const val TAG = "MarkdownSegmentRenderer"

  fun render(
    segments: List<MarkdownSegment>,
    style: StyleConfig,
    context: Context,
    imageRequestHeaders: Map<String, String> = emptyMap(),
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
    onPluginEvent: PluginEventSink? = null,
  ): List<RenderedSegment> {
    val plugins = EnrichedMarkdownPlugins.snapshot
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
          RenderedSegment.Table(segment.node, signature, imageRequestHeaders)
        }

        is MarkdownSegment.Custom -> {
          val plugin = plugins.blockSegmentFor(segment.pluginId)
          if (plugin == null) {
            Log.w(TAG, "Plugin '${segment.pluginId}' was uninstalled mid-render; rendering its node as text.")
          }
          // A null payload is the plugin declining this node - half-arrived content, say. Its
          // source still has to reach the screen, so it falls back to core text rendering.
          val payload = plugin?.renderPayload(segment.node, style, context)
          if (payload == null) {
            renderAsText(listOf(segment.node))
          } else {
            RenderedSegment.Custom(
              pluginId = segment.pluginId,
              payload = payload,
              signature = SegmentSignature.signatureForPluginSegment(segment.pluginId, payload.signatureSource),
            )
          }
        }
      }
    }
  }

  private fun renderTextSegment(
    nodes: List<MarkdownASTNode>,
    style: StyleConfig,
    context: Context,
    imageRequestHeaders: Map<String, String>,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    onPluginEvent: PluginEventSink?,
    startingTaskIndex: Int,
  ): Pair<RenderedSegment.Text, Int> {
    val renderer = Renderer().apply { configure(style, context, imageRequestHeaders, onPluginEvent) }
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
