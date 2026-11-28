package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.TextView
import com.swmansion.enriched.markdown.CodeBlockWrapCursor
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper
import com.swmansion.enriched.markdown.math.LatexErrorReporter
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.spans.BaseListSpan
import com.swmansion.enriched.markdown.spans.NativeListItemSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.spans.UnorderedListSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.layout.isLayoutRTL
import com.swmansion.enriched.markdown.utils.common.serialization.MarkdownASTSerializer
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import com.swmansion.enriched.markdown.utils.text.view.cancelJSTouchForCheckboxTap
import kotlin.math.ceil
import kotlin.math.max

/** Lists with tables need child views; ordinary lists retain the attributed-text renderer. */
class ListContainerView(
  context: Context,
  private val config: SegmentViewConfig,
) : ContainerNodeView(context),
  BlockSegmentView {
  private var depth = 0
  override val segmentMarginTop: Int get() =
    if (depth == 0) {
      config.style.listStyle.marginTop
        .toInt()
    } else {
      0
    }
  override val segmentMarginBottom: Int get() =
    if (depth == 0) {
      config.style.listStyle.marginBottom
        .toInt()
    } else {
      0
    }

  internal var outerRightToLeft: Boolean? = null
    set(value) {
      field = value
      applyQuoteSide()
    }

  private fun applyQuoteSide() {
    fun apply(view: View) {
      when (view) {
        is BlockquoteContainerView -> view.outerRightToLeft = outerRightToLeft
        is ListContainerView -> view.outerRightToLeft = outerRightToLeft
        is android.view.ViewGroup -> (0 until view.childCount).forEach { apply(view.getChildAt(it)) }
      }
    }
    segmentViews.forEach(::apply)
  }

  fun applyList(segment: RenderedSegment.ListBlock) {
    depth = segment.depth
    val previous = segmentViews.toList()
    val current =
      items(segment, config.style, context).mapIndexed { index, item ->
        (previous.getOrNull(index) as? ItemView)?.also { it.applyItem(item) }
          ?: ItemView(context, config, item).also { addView(it) }
      }
    previous.drop(current.size).forEach { removeView(it) }
    segmentViews.clear()
    segmentViews.addAll(current)
    applyQuoteSide()
    requestLayout()
  }

  override fun onMeasure(
    widthSpec: Int,
    heightSpec: Int,
  ) {
    val width = MeasureSpec.getSize(widthSpec)
    measureSegmentChildren(width)
    setMeasuredDimension(width, computeSegmentsTotalHeight())
  }

  override fun onLayout(
    changed: Boolean,
    l: Int,
    t: Int,
    r: Int,
    b: Int,
  ) = layoutSegments()

  private data class Item(
    val node: MarkdownASTNode,
    val number: Int,
    val marker: BaseListSpan,
    val indent: Int,
    val depth: Int,
    val taskIndex: Int,
    val spacing: Int,
    val withinBlockquote: Boolean,
    val rtl: Boolean,
  )

  private class ItemView(
    context: Context,
    private val config: SegmentViewConfig,
    private var item: Item,
  ) : ContainerNodeView(context),
    BlockSegmentView {
    override val segmentMarginBottom: Int get() = item.spacing
    private val checkbox =
      object : View(context) {
        override fun onTouchEvent(event: MotionEvent): Boolean {
          if (!config.dynamicProps.enableTaskListItemToggle) return false
          if (event.actionMasked == MotionEvent.ACTION_DOWN) cancelJSTouchForCheckboxTap(event)
          return super.onTouchEvent(event)
        }

        override fun performClick(): Boolean {
          if (!config.dynamicProps.enableTaskListItemToggle) return false
          return super.performClick()
        }

        override fun onInitializeAccessibilityNodeInfo(info: AccessibilityNodeInfo) {
          super.onInitializeAccessibilityNodeInfo(info)
          info.className = "android.widget.CheckBox"
          info.isCheckable = true
          info.isChecked = item.node.getAttribute("taskChecked") == "true"
          info.isEnabled = config.dynamicProps.enableTaskListItemToggle
        }
      }.apply {
        setOnClickListener {
          config.onTaskListItemPress?.invoke(
            item.taskIndex,
            item.node.getAttribute("taskChecked") == "true",
            MarkdownASTSerializer.plainText(item.node),
          )
        }
      }
    private val markerPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = config.style.listStyle.fontSize }

    init {
      setWillNotDraw(false)
      segmentViewFactory = NestedSegmentViewFactory(config, item.withinBlockquote)
      addView(checkbox)
      applyItem(item)
    }

    fun applyItem(next: Item) {
      item = next
      if (item.rtl) {
        setPadding(0, 0, item.indent, 0)
      } else {
        setPadding(item.indent, 0, 0, 0)
      }
      checkbox.visibility = if (item.node.getAttribute("isTask") == "true") VISIBLE else GONE
      checkbox.contentDescription = MarkdownASTSerializer.plainText(item.node)
      val rendered = renderBody(item, config.style, context, config.onLinkPress, config.onLinkLongPress, config.onLatexError)
      applySegments(rendered, reset = false)
      requestLayout()
      invalidate()
    }

    override fun onMeasure(
      widthSpec: Int,
      heightSpec: Int,
    ) {
      val width = MeasureSpec.getSize(widthSpec)
      measureSegmentChildren(width)
      setMeasuredDimension(width, max(ceil(config.style.listStyle.lineHeight).toInt(), computeSegmentsTotalHeight()))
    }

    override fun onLayout(
      changed: Boolean,
      l: Int,
      t: Int,
      r: Int,
      b: Int,
    ) {
      layoutSegments()
      val left = if (item.rtl) width - paddingRight else 0
      val marker = item.marker as? TaskListSpan
      val center = marker?.markerCenterY(markerBaseline()) ?: 0f
      val targetHeight = ceil(max(config.style.listStyle.lineHeight, config.style.taskListStyle.checkboxSize)).toInt()
      val top = (center - targetHeight / 2f).toInt()
      checkbox.layout(left, top, left + item.indent, top + targetHeight)
    }

    internal override fun addSegmentsForAccessibility(
      slotViews: Map<String, View>,
      outChildren: ArrayList<View>,
    ) {
      if (checkbox.visibility == VISIBLE) outChildren.add(checkbox)
      super.addSegmentsForAccessibility(slotViews, outChildren)
    }

    override fun addChildrenForAccessibility(outChildren: ArrayList<View>) {
      addSegmentsForAccessibility(slotViewsForAccessibility(), outChildren)
    }

    private fun contentBaseline(view: View): Int? {
      if (view is TextView && view.baseline >= 0) return view.baseline
      if (view is ViewGroup) {
        for (index in 0 until view.childCount) {
          val child = view.getChildAt(index)
          if (child.visibility != VISIBLE) continue
          val baseline = contentBaseline(child)
          if (baseline != null) return child.top + baseline
        }
      }
      return null
    }

    private fun markerBaseline(): Int {
      val first = segmentViews.firstOrNull()
      return first?.let { contentBaseline(it)?.plus(it.top) }
        ?: ((first?.top ?: 0) + ceil(-item.marker.markerFontMetrics.ascent).toInt())
    }

    override fun onDraw(canvas: Canvas) {
      super.onDraw(canvas)
      val baseline = markerBaseline()
      val style = config.style.listStyle
      val offset =
        item.indent - style.gapWidth.coerceAtLeast(4f) - item.marker.baselineMarkerWidth - item.marker.markerExtraWidth -
          item.depth * style.marginLeft
      val rtl = item.rtl
      val markerX = if (rtl) width - offset.toInt() else offset.toInt()
      item.marker.drawMarkerAt(canvas, markerPaint, markerX, if (rtl) -1 else 1, 0, baseline, height, null, 0)
    }
  }

  companion object {
    private fun items(
      segment: RenderedSegment.ListBlock,
      style: StyleConfig,
      context: Context,
    ): List<Item> {
      val list = style.listStyle
      val ordered = segment.node.type == NodeType.OrderedList
      val start =
        segment.node
          .getAttribute("start")
          ?.toIntOrNull()
          ?.coerceAtLeast(0) ?: 1
      val nodes = segment.node.children.filter { it.type == NodeType.ListItem }
      val extra =
        if (ordered) {
          OrderedListSpan.measureExtraWidth(
            list,
            context,
            nodes.mapIndexedNotNull { index, node ->
              if (node.getAttribute("isTask") ==
                "true"
              ) {
                null
              } else {
                start + index
              }
            },
          )
        } else {
          0f
        }
      val cache = SpanStyleCache(style)
      var taskIndex = segment.taskIndexOffset
      return nodes.mapIndexed { index, node ->
        val isTask = node.getAttribute("isTask") == "true"
        val marker =
          when {
            isTask -> {
              TaskListSpan(
                style.taskListStyle,
                list,
                segment.depth,
                context,
                cache,
                taskIndex,
                node.getAttribute("taskChecked") == "true",
                markerExtraWidth = extra,
                parentMarkerWidth = segment.parentMarkerWidth,
              )
            }

            ordered -> {
              OrderedListSpan(
                list,
                segment.depth,
                context,
                cache,
                markerExtraWidth = extra,
                parentMarkerWidth = segment.parentMarkerWidth,
              ).apply {
                setItemNumber(start + index)
              }
            }

            else -> {
              UnorderedListSpan(list, segment.depth, context, cache, parentMarkerWidth = segment.parentMarkerWidth)
            }
          }
        val plainText = MarkdownASTSerializer.plainText(node)
        val direction =
          if (context.resources.isLayoutRTL()) TextDirectionHeuristics.FIRSTSTRONG_RTL else TextDirectionHeuristics.FIRSTSTRONG_LTR
        val item =
          Item(
            node,
            start + index,
            marker,
            marker.getLeadingMargin(true),
            segment.depth,
            taskIndex,
            if (index ==
              nodes.lastIndex
            ) {
              0
            } else {
              ceil(list.itemSpacing).toInt()
            },
            segment.withinBlockquote,
            direction.isRtl(plainText, 0, plainText.length),
          )
        taskIndex += MarkdownSegmentRenderer.countTaskItems(node)
        item
      }
    }

    private fun renderBody(
      item: Item,
      style: StyleConfig,
      context: Context,
      onLinkPress: ((String) -> Unit)?,
      onLinkLongPress: (
        (String) -> Unit
      )?,
      onLatexError: LatexErrorReporter? = null,
    ): List<RenderedSegment> {
      val list = style.listStyle
      val paragraph =
        style.paragraphStyle.copy(
          fontSize = list.fontSize,
          fontFamily = list.fontFamily,
          fontWeight = list.fontWeight,
          color = list.color,
          lineHeight = list.lineHeight,
          marginTop = 0f,
          marginBottom = 0f,
        )
      val rendered =
        style.withParagraphOverride(paragraph) {
          MarkdownSegmentRenderer.render(
            splitASTIntoSegments(item.node, listContainer = true),
            style,
            context,
            onLinkPress,
            onLinkLongPress,
            startingTaskIndex = item.taskIndex + if (item.node.getAttribute("isTask") == "true") 1 else 0,
            listDepth = item.depth + 1,
            parentMarkerWidth = item.marker.baselineMarkerWidth,
            withinBlockquote = item.withinBlockquote,
            onLatexError = onLatexError,
          )
        }
      if (item.node.getAttribute("taskChecked") == "true") {
        for (segment in rendered.filterIsInstance<RenderedSegment.Text>()) {
          val text = requireNotNull(segment.styledText)
          if (style.taskListStyle.checkedStrikethrough) text.setSpan(StrikethroughSpan(), 0, text.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
          if (style.taskListStyle.checkedTextColor !=
            0
          ) {
            text.setSpan(ForegroundColorSpan(style.taskListStyle.checkedTextColor), 0, text.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
          }
        }
      }
      var inheritedSignature = SegmentSignature.LIST_KIND_SALT
      inheritedSignature = SegmentSignature.fnvMixLong(inheritedSignature, item.number.toLong())
      inheritedSignature = SegmentSignature.fnvMixLong(inheritedSignature, item.depth.toLong())
      inheritedSignature = SegmentSignature.fnvMixLong(inheritedSignature, item.taskIndex.toLong())
      inheritedSignature = SegmentSignature.fnvMixLong(inheritedSignature, if (item.marker is OrderedListSpan) 1 else 0)
      inheritedSignature = SegmentSignature.fnvMixString(inheritedSignature, item.node.getAttribute("isTask"))
      inheritedSignature = SegmentSignature.fnvMixString(inheritedSignature, item.node.getAttribute("taskChecked"))
      return rendered.map { segment ->
        if (segment is RenderedSegment.Text) {
          val text = requireNotNull(segment.styledText)
          text.setSpan(NativeListItemSpan(item.marker), 0, text.length, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
          text.setSpan(
            MarkdownAccessibilityHelper.ListItemInfo(item.marker is OrderedListSpan, item.number, item.depth),
            0,
            text.length,
            SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
          )
          segment.copy(signature = segment.signature xor inheritedSignature)
        } else {
          segment
        }
      }
    }

    fun measureListHeight(
      segment: RenderedSegment.ListBlock,
      style: StyleConfig,
      context: Context,
      width: Float,
      wrapCursor: CodeBlockWrapCursor?,
      slotMeasurer: BlockSlotMeasurer?,
      originX: Float,
      originY: Float,
      breakStrategy: Int,
      quoteRightToLeft: Boolean? = null,
    ): Float {
      var height = 0f
      for (item in items(segment, style, context)) {
        val body = renderBody(item, style, context, null, null)
        val bodyHeight =
          SegmentHeightMeasurer.measureSegmentsHeight(
            body,
            style,
            context,
            (ceil(width) - item.indent).coerceAtLeast(1f),
            style.listStyle.fontSize,
            breakStrategy,
            false,
            { style.mathStyle.fontSize * 1.4f + style.mathStyle.padding * 2 },
            wrapCursor,
            slotMeasurer,
            originX + if (item.rtl) 0 else item.indent,
            originY + height,
            quoteRightToLeft = quoteRightToLeft,
            nestedBlockquote = item.withinBlockquote,
          )
        height += max(ceil(style.listStyle.lineHeight), bodyHeight) + item.spacing
      }
      return height
    }
  }
}
