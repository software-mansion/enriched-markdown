package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.text.SpannableString
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.StyleConfig

sealed interface RenderedSegment {
  val signature: Long

  data class Text(
    val styledText: SpannableString,
    val imageSpans: List<ImageSpan>,
    val needsJustify: Boolean,
    val lastElementMarginBottom: Float,
    override val signature: Long,
  ) : RenderedSegment

  data class Table(
    val node: MarkdownASTNode,
    override val signature: Long,
  ) : RenderedSegment
}

object MarkdownSegmentRenderer {
  fun render(
    segments: List<MarkdownSegment>,
    style: StyleConfig,
    context: Context,
    imageRequestHeaders: Map<String, String> = emptyMap(),
    onLinkPress: ((String) -> Unit)? = null,
    onLinkLongPress: ((String) -> Unit)? = null,
  ): List<RenderedSegment> {
    // Task indices must stay document-global: each Text segment gets a fresh Renderer,
    // so the running count is threaded through explicitly rather than reset per segment.
    var taskIndexOffset = 0
    return segments.map { segment ->
      when (segment) {
        is MarkdownSegment.Text -> {
          val (rendered, taskItemCount) =
            renderTextSegment(segment.nodes, style, context, imageRequestHeaders, onLinkPress, onLinkLongPress, taskIndexOffset)
          taskIndexOffset = taskItemCount
          rendered
        }

        is MarkdownSegment.Table -> {
          val signature = SegmentSignature.signatureForNode(segment.node) xor SegmentSignature.TABLE_KIND_SALT
          RenderedSegment.Table(segment.node, signature)
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
    startingTaskIndex: Int,
  ): Pair<RenderedSegment.Text, Int> {
    val renderer = Renderer().apply { configure(style, context, imageRequestHeaders) }
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
