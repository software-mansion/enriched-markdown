package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.util.TypedValue
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListHitTestResult
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectionColors

data class SegmentViewConfig(
  val context: Context,
  val style: StyleConfig,
  val selectable: Boolean,
  val selectionColor: Int?,
  val selectionHandleColor: Int?,
  val selectionMenuConfig: SelectionMenuConfig,
  val enableTaskListItemToggle: Boolean,
  val onTaskListItemTap: ((view: EnrichedMarkdownInternalText, hit: TaskListHitTestResult) -> Unit)?,
)

object SegmentViewCreators {
  fun createTextView(
    segment: RenderedSegment.Text,
    config: SegmentViewConfig,
  ): EnrichedMarkdownInternalText =
    EnrichedMarkdownInternalText(config.context).apply {
      selectionMenuConfig = config.selectionMenuConfig
      setIsSelectable(config.selectable)
      setTextSize(TypedValue.COMPLEX_UNIT_PX, config.style.paragraphStyle.fontSize)
      setJustificationMode(segment.needsJustify)
      enableTaskListItemToggle = config.enableTaskListItemToggle
      onTaskListItemTapCallback = { hit -> config.onTaskListItemTap?.invoke(this, hit) }
      lastElementMarginBottom = segment.lastElementMarginBottom
      applyStyledText(segment.styledText)
      segment.imageSpans.forEach { it.registerTextView(this) }
      applySelectionColors(config.selectionColor, config.selectionHandleColor)
    }

  fun updateTextView(
    view: EnrichedMarkdownInternalText,
    segment: RenderedSegment.Text,
  ) {
    view.lastElementMarginBottom = segment.lastElementMarginBottom
    view.applyStyledText(segment.styledText)
    segment.imageSpans.forEach { it.registerTextView(view) }
  }

  fun createTableView(
    segment: RenderedSegment.Table,
    config: SegmentViewConfig,
  ): TableContainerView =
    TableContainerView(config.context, config.style).apply {
      selectionMenuConfig = config.selectionMenuConfig
      applyTableNode(segment.node)
    }

  fun updateTableView(
    view: TableContainerView,
    segment: RenderedSegment.Table,
  ) {
    view.applyTableNode(segment.node)
  }
}
