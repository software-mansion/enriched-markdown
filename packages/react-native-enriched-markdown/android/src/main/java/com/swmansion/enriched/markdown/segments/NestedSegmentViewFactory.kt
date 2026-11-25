package com.swmansion.enriched.markdown.segments

import android.view.View
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText

internal class NestedSegmentViewFactory(
  private val config: SegmentViewConfig,
  private val withinBlockquote: Boolean,
) : SegmentViewFactory {
  override fun matchesKind(
    view: View,
    segment: RenderedSegment,
  ): Boolean =
    when (segment) {
      is RenderedSegment.Text -> view is EnrichedMarkdownInternalText
      is RenderedSegment.Table -> view is TableContainerView
      is RenderedSegment.ListBlock -> view is ListContainerView
      is RenderedSegment.Blockquote -> view is BlockquoteContainerView
      is RenderedSegment.CodeBlock -> view is CodeBlockContainerView
      is RenderedSegment.Math -> SegmentViewCreators.isMathContainerView(view)
      is RenderedSegment.Video -> SegmentViewCreators.isVideoContainerView(view)
      is RenderedSegment.BlockSlot -> view is BlockSlotSegmentView
    }

  override fun createView(segment: RenderedSegment): View =
    when (segment) {
      is RenderedSegment.Text -> SegmentViewCreators.createTextView(segment, config)
      is RenderedSegment.Table -> SegmentViewCreators.createTableView(segment, config)
      is RenderedSegment.ListBlock -> ListContainerView(config.context, config).apply { applyList(segment) }
      is RenderedSegment.Blockquote -> SegmentViewCreators.createBlockquoteView(segment, config).apply { nested = withinBlockquote }
      is RenderedSegment.CodeBlock -> SegmentViewCreators.createCodeBlockView(segment, config)
      is RenderedSegment.Math -> SegmentViewCreators.createMathView(segment, config)
      is RenderedSegment.Video -> SegmentViewCreators.createVideoView(segment, config)
      is RenderedSegment.BlockSlot -> SegmentViewCreators.createBlockSlotView(segment, config)
    }.also { config.configureView?.invoke(it) }

  override fun updateView(
    view: View,
    segment: RenderedSegment,
  ) {
    when (segment) {
      is RenderedSegment.Text -> {
        SegmentViewCreators.updateTextView(view as EnrichedMarkdownInternalText, segment)
      }

      is RenderedSegment.Table -> {
        (view as TableContainerView).applyTableNode(segment.node)
      }

      is RenderedSegment.ListBlock -> {
        (view as ListContainerView).applyList(segment)
      }

      is RenderedSegment.Blockquote -> {
        (view as BlockquoteContainerView).applyBlockquoteNode(
          segment.node,
          segment.taskIndexOffset,
          segment.listDepth,
          segment.parentMarkerWidth,
        )
      }

      is RenderedSegment.CodeBlock -> {
        (view as CodeBlockContainerView).applyCodeBlockNode(segment.node)
      }

      is RenderedSegment.Math -> {
        SegmentViewCreators.updateMathView(view, segment)
      }

      is RenderedSegment.Video -> {
        SegmentViewCreators.updateVideoView(view, segment)
      }

      is RenderedSegment.BlockSlot -> {
        SegmentViewCreators.updateBlockSlotView(view as BlockSlotSegmentView, segment)
      }
    }
  }

  override fun animateNewView(
    view: View,
    segment: RenderedSegment,
  ) = Unit
}
