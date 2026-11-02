package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.text.Spannable
import com.swmansion.enriched.markdown.math.LatexErrorReporter
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.BlockquoteTextRenderer
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.BlockquoteStyle
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
  ) : RenderedSegment

  data class Math(
    val latex: String,
    override val signature: Long,
  ) : RenderedSegment

  data class CodeBlock(
    val node: MarkdownASTNode,
    override val signature: Long,
  ) : RenderedSegment

  data class Blockquote(
    val node: MarkdownASTNode,
    override val signature: Long,
    /** Document-global index of the quote's first task-list item. */
    val taskIndexOffset: Int = 0,
  ) : RenderedSegment

  data class Video(
    val node: MarkdownASTNode,
    override val signature: Long,
  ) : RenderedSegment

  data class BlockSlot(
    val slotId: String,
    val kind: BlockSlotKind,
    override val signature: Long,
  ) : RenderedSegment
}

object MarkdownSegmentRenderer {
  fun render(
    segments: List<MarkdownSegment>,
    style: StyleConfig,
    context: Context,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    blockquoteStyle: BlockquoteStyle? = null,
    onLatexError: LatexErrorReporter? = null,
    startingTaskIndex: Int = 0,
  ): List<RenderedSegment> {
    var taskIndexOffset = startingTaskIndex

    return segments.map { segment ->
      when (segment) {
        is MarkdownSegment.Text -> {
          val (rendered, taskItemCount) =
            renderTextSegment(
              segment.nodes,
              style,
              context,
              onLinkPress,
              onLinkLongPress,
              blockquoteStyle,
              onLatexError,
              taskIndexOffset,
            )
          taskIndexOffset = taskItemCount
          rendered
        }

        is MarkdownSegment.Table -> {
          val signature = SegmentSignature.signatureForNode(segment.node) xor SegmentSignature.TABLE_KIND_SALT
          RenderedSegment.Table(segment.node, signature)
        }

        is MarkdownSegment.Math -> {
          var signature = SegmentSignature.signatureForNode(null) xor SegmentSignature.MATH_KIND_SALT
          signature = SegmentSignature.fnvMixString(signature, segment.latex)
          RenderedSegment.Math(segment.latex, signature)
        }

        is MarkdownSegment.CodeBlock -> {
          val signature = SegmentSignature.signatureForNode(segment.node) xor SegmentSignature.CODE_BLOCK_KIND_SALT
          RenderedSegment.CodeBlock(segment.node, signature)
        }

        is MarkdownSegment.Blockquote -> {
          val taskItemCount = countTaskItems(segment.node)
          val signature =
            SegmentSignature.withTaskIndexOffset(
              SegmentSignature.signatureForNode(segment.node) xor SegmentSignature.BLOCKQUOTE_KIND_SALT,
              taskIndexOffset,
              hasTasks = taskItemCount > 0,
            )
          RenderedSegment.Blockquote(segment.node, signature, taskIndexOffset).also {
            taskIndexOffset += taskItemCount
          }
        }

        is MarkdownSegment.Video -> {
          val signature = SegmentSignature.signatureForNode(segment.node) xor SegmentSignature.VIDEO_KIND_SALT
          RenderedSegment.Video(segment.node, signature)
        }

        is MarkdownSegment.BlockSlot -> {
          val signature =
            SegmentSignature.fnvMixString(SegmentSignature.signatureForNode(null), segment.slotId) xor
              SegmentSignature.BLOCK_SLOT_KIND_SALT
          RenderedSegment.BlockSlot(segment.slotId, segment.kind, signature)
        }
      }
    }
  }

  /**
   * Task-list items in [node]'s subtree, counted as ListItemRenderer numbers them. Used for a
   * blockquote, whose children render only when its container view applies the node.
   */
  private fun countTaskItems(node: MarkdownASTNode): Int {
    val own = if (node.type == MarkdownASTNode.NodeType.ListItem && node.getAttribute("isTask") == "true") 1 else 0
    return own + node.children.sumOf { countTaskItems(it) }
  }

  private fun renderTextSegment(
    nodes: List<MarkdownASTNode>,
    style: StyleConfig,
    context: Context,
    onLinkPress: ((String) -> Unit)?,
    onLinkLongPress: ((String) -> Unit)?,
    blockquoteStyle: BlockquoteStyle?,
    onLatexError: LatexErrorReporter?,
    startingTaskIndex: Int,
  ): Pair<RenderedSegment.Text, Int> {
    val renderer = Renderer().apply { configure(style, context, onLatexError) }

    val styledText =
      if (blockquoteStyle != null) {
        BlockquoteTextRenderer(blockquoteStyle).render(renderer, nodes, onLinkPress, onLinkLongPress, startingTaskIndex)
      } else {
        renderer.renderContent(nodes, onLinkPress, onLinkLongPress, startingTaskIndex = startingTaskIndex)
      }

    val taskItemCount = renderer.getTaskItemCount()
    val signature =
      SegmentSignature.withTaskIndexOffset(
        SegmentSignature.signatureForNodes(nodes) xor SegmentSignature.TEXT_KIND_SALT,
        startingTaskIndex,
        hasTasks = taskItemCount > startingTaskIndex,
      )

    val rendered =
      RenderedSegment.Text(
        styledText = styledText,
        imageSpans = renderer.getCollectedImageSpans().toList(),
        needsJustify = style.needsJustify,
        lastElementMarginBottom = renderer.getLastElementMarginBottom(),
        signature = signature,
      )

    return rendered to taskItemCount
  }
}
