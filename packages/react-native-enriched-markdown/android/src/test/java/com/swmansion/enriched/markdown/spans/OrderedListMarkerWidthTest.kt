package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.text.SpannableString
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListTapUtils
import com.swmansion.enriched.markdown.utils.text.view.setupAsMarkdownTextView
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class OrderedListMarkerWidthTest {
  private val context = RuntimeEnvironment.getApplication()

  @Test
  fun shortListsKeepTheirIndentAndLongListsShareTheirWidestGutter() {
    val config = styleConfig()
    val paint =
      TextPaint().apply {
        textSize = config.listStyle.fontSize
        typeface = Typeface.create("monospace", Typeface.NORMAL)
      }
    val baseline = paint.measureText("99.")
    val short = render(config, list(1, 99))
    short.forEach { assertEquals((baseline + config.listStyle.gapWidth).toInt(), it.getLeadingMargin(false)) }
    for ((start, count) in listOf(1 to 250, 98 to 4, 998 to 4, 12345 to 4, 0 to 101)) {
      val spans = render(config, list(start, count))
      val widest = maxOf(baseline, spans.maxOf { paint.measureText("${it.itemNumber}.") })
      spans.forEach { assertEquals((widest + config.listStyle.gapWidth).toInt(), it.getLeadingMargin(false)) }
      assertTrue(spans.first().getLeadingMargin(false) > short.first().getLeadingMargin(false))
    }
  }

  @Test
  fun nestedAndFollowingListsRestoreTheirOwnGutters() {
    val config = styleConfig()
    val outer = list(98, 4)
    val first = outer.children.first()
    val nested = outer.copy(children = listOf(first.copy(children = first.children + list(9998, 4))) + outer.children.drop(1))
    val spans = render(config, nested, list(1, 1))
    val parent = spans.filter { it.depth == 0 && it.itemNumber != 1 }
    assertEquals(4, parent.size)
    parent.forEach { assertEquals(parent.first().getLeadingMargin(false), it.getLeadingMargin(false)) }
    spans.filter { it.depth == 1 }.forEach { assertTrue(it.getLeadingMargin(false) > config.listStyle.marginLeft) }
    val following = spans.single { it.depth == 0 && it.itemNumber == 1 }
    assertTrue(following.getLeadingMargin(false) < parent.first().getLeadingMargin(false))
  }

  @Test
  fun markerMinimumWidthRemainsAFloor() {
    val config = styleConfig(200.0)
    render(config, list(998, 4)).forEach {
      assertEquals((config.listStyle.markerMinWidth + config.listStyle.gapWidth).toInt(), it.getLeadingMargin(false))
    }
  }

  @Test
  fun drawnMarkersStayInsideTheGutterAndAttachedToTheirParagraphs() {
    for (start in listOf(1, 98, 9998)) {
      val config = styleConfig()
      val outer = list(start, 4)
      val parent = outer.children[2]
      val middle = list(1, 1)
      val child = middle.children[0]
      val threeLevels = middle.copy(children = listOf(child.copy(children = child.children + list(1, 1))))
      val nested =
        outer.copy(
          children =
            outer.children.take(2) + parent.copy(children = parent.children + threeLevels) + outer.children.drop(3),
        )
      assertDrawnMarkerPositions(config, nested)
    }
  }

  @Test
  fun nestedBulletColumnsKeepTheirGapUnderWideParents() {
    val config = styleConfig()

    fun tree(start: Int): MarkdownASTNode {
      val outer = list(start, 4)
      val parent = outer.children[2]
      val bullets = list(1, 2).copy(type = NodeType.UnorderedList)
      return outer.copy(
        children = outer.children.take(2) + parent.copy(children = parent.children + bullets) + outer.children.drop(3),
      )
    }
    for (start in listOf(98, 9998)) {
      assertNestedMarkerGapsUnchanged(config, tree(1), tree(start))
    }
  }

  @Test
  fun tasksDoNotPassTheWideListsNumericExtraToTheirChildren() {
    val config = styleConfig()

    fun tree(start: Int): MarkdownASTNode {
      val outer = list(start, 3)
      val task = outer.children[1]
      val taskWithChild = task.copy(attributes = mapOf("isTask" to "true"), children = task.children + list(1, 1))
      val numeric = outer.children[2]
      val numericWithChild = numeric.copy(children = numeric.children + list(1, 1))
      return outer.copy(children = listOf(outer.children[0], taskWithChild, numericWithChild))
    }
    assertNestedMarkerGapsUnchanged(config, tree(1), tree(12345))
  }

  @Test
  fun nestedTasksKeepTheirGapUnderWideNumericParents() {
    val config = styleConfig()

    fun tree(start: Int): MarkdownASTNode {
      val outer = list(start, 4)
      val parent = outer.children[2]
      val nested = list(1, 1)
      val task = nested.children[0].copy(attributes = mapOf("isTask" to "true"))
      val taskList = nested.copy(children = listOf(task))
      return outer.copy(
        children = outer.children.take(2) + parent.copy(children = parent.children + taskList) + outer.children.drop(3),
      )
    }
    for (start in listOf(98, 9998)) {
      assertNestedMarkerGapsUnchanged(config, tree(1), tree(start))
    }
  }

  @Test
  fun togglingATaskUnderAWideParentKeepsEveryMarginAndMarkerPosition() {
    assertTaskToggleKeepsGeometry(opensWithSublist = false)
  }

  @Test
  fun togglingAnAnchoredTaskUnderAWideParentKeepsEveryMarginAndMarkerPosition() {
    assertTaskToggleKeepsGeometry(opensWithSublist = true)
  }

  @Test
  fun sameTypeBulletAndTaskNestsKeepTheirMarkerGap() {
    val config = styleConfig()
    val ordered = list(1, 1)
    val bullet = ordered.copy(type = NodeType.UnorderedList)
    val task = ordered.copy(children = listOf(ordered.children[0].copy(attributes = mapOf("isTask" to "true"))))
    for (parent in listOf(bullet, task)) {
      val item = parent.children[0]
      assertDrawnMarkerPositions(config, parent.copy(children = listOf(item.copy(children = item.children + parent))))
    }
  }

  @Test
  fun shortMixedNestsKeepTheirOriginalTextIndents() {
    val config = styleConfig(fontFamily = "", gapWidth = 6.0, checkboxSize = 14.0)
    val ordered = list(1, 1)
    val bullet = ordered.copy(type = NodeType.UnorderedList)
    val task = ordered.copy(children = listOf(ordered.children[0].copy(attributes = mapOf("isTask" to "true"))))
    val shapes = listOf(ordered to bullet, bullet to ordered, bullet to task, ordered to task, task to bullet)
    val baseIndents = listOf(52f, 33f, 33f, 52f, 44f)
    for ((index, shape) in shapes.withIndex()) {
      val (parent, child) = shape
      val tree = parent.copy(children = listOf(parent.children[0].copy(children = parent.children[0].children + child)))
      val nested = drawMarkers(config, tree).single { it.depth == 1 }
      assertEquals("base mixed indent for shape $index", baseIndents[index], nested.paragraphLeft, 0.01f)
      assertTrue(nested.marker.left >= 0f)
    }
  }

  @Test
  fun markersAnchoredOnANestedListKeepTheirAncestorsOffset() {
    val config = styleConfig()
    val outer = list(12345, 1)
    val middle = list(1, 1)
    val openingSublist = middle.children[0].copy(children = listOf(list(1, 1)))
    val renderer = Renderer()
    renderer.configure(config, context)
    val nested =
      outer.copy(
        children =
          listOf(
            outer.children[0].copy(
              children =
                outer.children[0].children + middle.copy(children = listOf(openingSublist)),
            ),
          ),
      )
    val text = SpannableString(renderer.renderContent(listOf(nested)))
    assertEquals(1, text.getSpans(0, text.length, ListMarkerAnchorSpan::class.java).size)
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, TextPaint(), 2000).build()
    val canvas = MarkerCanvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888))
    layout.draw(canvas)
    assertEquals(3, canvas.markers.size)
    val markersByColumn = canvas.markers.sortedBy { it.right }
    val root = markersByColumn[0]
    val anchored = markersByColumn[1]
    val leaf = markersByColumn[2]
    assertEquals(root.right + config.listStyle.marginLeft, anchored.right, 0.01f)
    assertEquals(anchored.right + config.listStyle.marginLeft, leaf.right, 0.01f)
    assertTrue(canvas.markers.all { it.left >= 0f })
  }

  @Test
  fun inheritedMarkerOffsetsFollowTheRtlDirection() {
    val config = styleConfig()
    val outer = list(12345, 1)
    val renderer = Renderer()
    renderer.configure(config, context)
    val nested = outer.copy(children = listOf(outer.children[0].copy(children = outer.children[0].children + list(1, 1))))
    val text = SpannableString(renderer.renderContent(listOf(nested)))
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, TextPaint(), 2000)
        .setTextDirection(android.text.TextDirectionHeuristics.RTL)
        .build()
    val canvas = MarkerCanvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888))
    layout.draw(canvas)
    assertEquals(2, canvas.markers.size)
    canvas.markers.forEach { marker ->
      val line = layout.getLineForVertical(marker.baseline.toInt())
      assertEquals(-1, layout.getParagraphDirection(line))
      assertEquals(layout.getParagraphRight(line) + config.listStyle.gapWidth, marker.left, 0.01f)
      assertTrue(marker.right <= layout.width)
    }
  }

  private fun assertTaskToggleKeepsGeometry(opensWithSublist: Boolean) {
    val config = styleConfig()
    val outer = list(100, 2)
    val nested = list(1, 1).copy(type = NodeType.UnorderedList)
    val taskItem = nested.children.single()
    val taskChildren = if (opensWithSublist) listOf(list(1, 1)) else taskItem.children + list(1, 1)
    val task = taskItem.copy(attributes = mapOf("isTask" to "true"), children = taskChildren)
    val parent = outer.children.first()
    val tree =
      outer.copy(
        children =
          listOf(parent.copy(children = parent.children + nested.copy(children = listOf(task)))) + outer.children.drop(1),
      )
    val renderer = Renderer()
    renderer.configure(config, context)
    val textView =
      object : AccessibleMarkdownTextView(context) {}.apply {
        layoutParams = ViewGroup.LayoutParams(2000, ViewGroup.LayoutParams.WRAP_CONTENT)
        setupAsMarkdownTextView()
      }
    textView.setText(renderer.renderContent(listOf(tree)), TextView.BufferType.SPANNABLE)
    val initialText = textView.text as Spanned
    val taskIndex = initialText.getSpans(0, initialText.length, TaskListSpan::class.java).single().taskIndex
    assertEquals(if (opensWithSublist) 1 else 0, initialText.getSpans(0, initialText.length, ListMarkerAnchorSpan::class.java).size)
    val initialMargins = listMargins(initialText)
    val initialMarkers = drawTextViewMarkers(textView)
    assertEquals(4, initialMarkers.size)

    for (checked in listOf(true, false)) {
      assertTrue(TaskListTapUtils.updateTaskListItemCheckedState(textView, taskIndex, checked, config))
      val text = textView.text as Spanned
      val tasks = text.getSpans(0, text.length, TaskListSpan::class.java)
      assertTrue(tasks.isNotEmpty())
      tasks.forEach { assertEquals(checked, it.isChecked) }
      text.getSpans(0, text.length, ListMarkerAnchorSpan::class.java).forEach {
        assertEquals(checked, (it.marker as TaskListSpan).isChecked)
      }
      assertEquals("list margins after checked=$checked", initialMargins, listMargins(text))
      assertEquals("drawn markers after checked=$checked", initialMarkers, drawTextViewMarkers(textView))
    }
  }

  private fun listMargins(text: Spanned): List<List<Int>> =
    text
      .getSpans(0, text.length, BaseListSpan::class.java)
      .sortedWith(compareBy({ text.getSpanStart(it) }, { it.depth }, { text.getSpanEnd(it) }))
      .map { listOf(text.getSpanStart(it), text.getSpanEnd(it), it.depth, it.getLeadingMargin(true), it.getLeadingMargin(false)) }

  private fun drawTextViewMarkers(textView: TextView): List<DrawnMarker> {
    textView.forceLayout()
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(2000, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, textView.measuredWidth, textView.measuredHeight)
    val canvas = MarkerCanvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888))
    textView.layout.draw(canvas)
    return canvas.markers.sortedWith(compareBy({ it.baseline }, { it.left }))
  }

  private fun assertDrawnMarkerPositions(
    config: StyleConfig,
    vararg lists: MarkdownASTNode,
  ) {
    drawMarkers(config, *lists).forEach { geometry ->
      assertEquals(
        "marker right at depth ${geometry.depth}",
        geometry.paragraphLeft - config.listStyle.gapWidth,
        geometry.marker.right,
        0.01f,
      )
    }
  }

  private fun assertNestedMarkerGapsUnchanged(
    config: StyleConfig,
    short: MarkdownASTNode,
    wide: MarkdownASTNode,
  ) {
    val shortMarkers = drawMarkers(config, short).filter { it.depth > 0 }
    val wideMarkers = drawMarkers(config, wide).filter { it.depth > 0 }
    assertTrue(shortMarkers.isNotEmpty())
    assertEquals(shortMarkers.size, wideMarkers.size)
    shortMarkers.zip(wideMarkers).forEach { (control, actual) ->
      assertEquals(control.depth, actual.depth)
      assertEquals(
        "nested marker gap at depth ${actual.depth}",
        control.paragraphLeft - control.marker.right,
        actual.paragraphLeft - actual.marker.right,
        0.01f,
      )
    }
  }

  private fun drawMarkers(
    config: StyleConfig,
    vararg lists: MarkdownASTNode,
  ): List<MarkerGeometry> {
    val renderer = Renderer()
    renderer.configure(config, context)
    // The view exposes spans in insertion order, as SpannableString does.
    val text = SpannableString(renderer.renderContent(lists.toList()))
    val paint = TextPaint().apply { textSize = config.listStyle.fontSize }
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, 2000).build()
    val canvas = MarkerCanvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888))
    layout.draw(canvas)
    assertEquals(text.getSpans(0, text.length, BaseListSpan::class.java).count { it.drawsMarker }, canvas.markers.size)
    return canvas.markers.map { marker ->
      val line = layout.getLineForVertical(marker.baseline.toInt())
      assertTrue("marker left ${marker.left} on line $line", marker.left >= 0f)
      val start = layout.getLineStart(line)
      val depth = text.getSpans(start, start + 1, BaseListSpan::class.java).maxOf { it.depth }
      MarkerGeometry(marker, layout.getParagraphLeft(line).toFloat(), depth)
    }
  }

  private data class MarkerGeometry(
    val marker: DrawnMarker,
    val paragraphLeft: Float,
    val depth: Int,
  )

  private data class DrawnMarker(
    val left: Float,
    val right: Float,
    val baseline: Float,
  )

  private class MarkerCanvas(
    bitmap: Bitmap,
  ) : Canvas(bitmap) {
    val markers = mutableListOf<DrawnMarker>()

    override fun drawCircle(
      cx: Float,
      cy: Float,
      radius: Float,
      paint: Paint,
    ) {
      // Bullets are centered on the reserved column edge, matching the iOS drawer.
      val outerRadius = radius + paint.strokeWidth / 2f
      markers += DrawnMarker(cx - outerRadius, cx, cy)
      super.drawCircle(cx, cy, radius, paint)
    }

    override fun drawRoundRect(
      rect: android.graphics.RectF,
      rx: Float,
      ry: Float,
      paint: Paint,
    ) {
      val halfStroke = if (paint.style == Paint.Style.STROKE) paint.strokeWidth / 2f else 0f
      markers += DrawnMarker(rect.left - halfStroke, rect.right + halfStroke, rect.centerY())
      super.drawRoundRect(rect, rx, ry, paint)
    }

    override fun drawText(
      text: String,
      x: Float,
      y: Float,
      paint: Paint,
    ) {
      if (text.matches(Regex("(?:[0-9]+\\.|\\.[0-9]+)"))) markers += DrawnMarker(x, x + paint.measureText(text), y)
      super.drawText(text, x, y, paint)
    }
  }

  private fun render(
    config: StyleConfig,
    vararg lists: MarkdownASTNode,
  ): List<OrderedListSpan> {
    val renderer = Renderer()
    renderer.configure(config, context)
    val text = renderer.renderContent(lists.toList())
    return text.getSpans(0, text.length, OrderedListSpan::class.java).toList()
  }

  private fun list(
    start: Int,
    count: Int,
  ) = MarkdownASTNode(
    NodeType.OrderedList,
    attributes = mapOf("start" to start.toString()),
    children =
      List(count) {
        MarkdownASTNode(
          NodeType.ListItem,
          children = listOf(MarkdownASTNode(NodeType.Paragraph, children = listOf(MarkdownASTNode(NodeType.Text, "item")))),
        )
      },
  )

  private fun styleConfig(
    minWidth: Double = 0.0,
    fontFamily: String = "monospace",
    gapWidth: Double = 8.0,
    checkboxSize: Double = 16.0,
  ): StyleConfig {
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)

    fun element() =
      JavaOnlyMap.of(
        "fontFamily",
        "",
        "fontWeight",
        "normal",
        "fontSize",
        16.0,
        "lineHeight",
        0.0,
        "marginTop",
        0.0,
        "marginBottom",
        0.0,
        "color",
        Color.BLACK,
        "backgroundColor",
        Color.TRANSPARENT,
        "borderColor",
        Color.TRANSPARENT,
        "underline",
        false,
        "fontScale",
        0.8,
        "baselineOffsetScale",
        0.5,
      )

    val style = JavaOnlyMap()
    listOf("paragraph", "strong", "em", "strikethrough", "code", "superscript", "subscript", "highlight")
      .forEach { style.putMap(it, element()) }
    style.putMap("link", element().apply { putString("fontFamily", "serif") })
    style.putArray(
      "linkVariants",
      JavaOnlyArray.of(
        element().apply {
          putString("pattern", "^ref:")
          putString("fontFamily", "monospace")
          putInt("color", Color.BLUE)
        },
      ),
    )
    style.putMap(
      "spoiler",
      element().apply {
        putMap("particles", JavaOnlyMap.of("density", 0.5, "speed", 1.0))
        putMap("solid", JavaOnlyMap.of("borderRadius", 0.0))
      },
    )
    style.putMap(
      "taskList",
      JavaOnlyMap.of(
        "checkedColor",
        Color.BLACK,
        "borderColor",
        Color.BLACK,
        "checkmarkColor",
        Color.BLACK,
        "checkedTextColor",
        Color.BLACK,
        "checkboxSize",
        checkboxSize,
        "checkboxBorderRadius",
        0.0,
        "checkedStrikethrough",
        false,
      ),
    )
    style.putMap(
      "list",
      element().apply {
        putString("fontFamily", fontFamily)
        putInt("bulletColor", Color.BLACK)
        putInt("markerColor", Color.BLACK)
        putDouble("bulletSize", 6.0)
        putDouble("markerMinWidth", minWidth)
        putDouble("gapWidth", gapWidth)
        putDouble("marginLeft", 24.0)
        putDouble("itemSpacing", 0.0)
      },
    )
    return StyleConfig(style, context, false, 0f)
  }
}
