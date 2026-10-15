package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Typeface
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class OrderedListMarkerWidthTest {
  @Test
  fun shortListsKeepTheirIndentAndLongListsShareTheirWidestGutter() {
    val style = styleConfig()
    val paint =
      TextPaint().apply {
        textSize = style.listStyle.fontSize
        typeface = Typeface.create("monospace", Typeface.NORMAL)
      }
    val baseline = paint.measureText("99.")
    val gap = style.listStyle.gapWidth
    val short = orderedSpans(style, numbered(99))
    short.forEach { assertEquals((baseline + gap).toInt(), it.getLeadingMargin(false)) }
    for (count in listOf(100, 101, 250, 1000)) {
      val spans = orderedSpans(style, numbered(count))
      val widest = maxOf(baseline, spans.maxOf { paint.measureText("${it.itemNumber}.") })
      spans.forEach { assertEquals((widest + gap).toInt(), it.getLeadingMargin(false)) }
      assertTrue(spans.first().getLeadingMargin(false) > short.first().getLeadingMargin(false))
    }
  }

  @Test
  fun nestedAndFollowingListsRestoreTheirOwnGutters() {
    val style = styleConfig()
    val outer = withChild(numbered(101), 0, numbered(1000))
    val spans = orderedSpans(style, outer, numbered(1))
    val parent = spans.filter { it.depth == 0 }.dropLast(1)
    assertEquals(101, parent.size)
    parent.forEach { assertEquals(parent.first().getLeadingMargin(false), it.getLeadingMargin(false)) }
    spans.filter { it.depth == 1 }.forEach { assertTrue(it.getLeadingMargin(false) > style.listStyle.marginLeft) }
    val following = spans.last()
    assertEquals(0, following.depth)
    assertTrue(following.getLeadingMargin(false) < parent.first().getLeadingMargin(false))
  }

  @Test
  fun markerMinimumWidthRemainsAFloor() {
    val style = styleConfig(minWidth = 200f)
    orderedSpans(style, numbered(101)).forEach {
      assertEquals((style.listStyle.markerMinWidth + style.listStyle.gapWidth).toInt(), it.getLeadingMargin(false))
    }
  }

  @Test
  fun drawnMarkersStayInsideTheGutterAndAttachedToTheirParagraphs() {
    val style = styleConfig()
    for (count in listOf(4, 101, 1000)) {
      val threeLevels = withChild(numbered(1), 0, numbered(1))
      drawMarkers(style, withChild(numbered(count), 2, threeLevels)).forEach { geometry ->
        assertEquals(
          "marker right at depth ${geometry.depth} in a list of $count",
          geometry.paragraphLeft - style.listStyle.gapWidth,
          geometry.marker.right,
          0.01f,
        )
      }
    }
  }

  @Test
  fun nestedBulletColumnsKeepTheirGapUnderWideParents() {
    val style = styleConfig()

    fun tree(count: Int) = withChild(numbered(count), 2, unorderedList(item(), item()))
    for (count in listOf(101, 1000)) {
      assertNestedMarkerGapsUnchanged(style, tree(4), tree(count))
    }
  }

  @Test
  fun tasksDoNotPassTheWideListsNumericExtraToTheirChildren() {
    val style = styleConfig()

    fun tree(count: Int): MarkdownASTNode {
      val items = numbered(count).children.toMutableList()
      items[1] = taskListItem(checked = false, paragraph(text("task")), numbered(1))
      items[2] = listItem(paragraph(text("item")), numbered(1))
      return orderedList(*items.toTypedArray())
    }
    assertNestedMarkerGapsUnchanged(style, tree(4), tree(1000))
  }

  @Test
  fun nestedTasksKeepTheirGapUnderWideNumericParents() {
    val style = styleConfig()

    fun tree(count: Int) = withChild(numbered(count), 2, orderedList(taskListItem(checked = false, paragraph(text("task")))))
    for (count in listOf(101, 1000)) {
      assertNestedMarkerGapsUnchanged(style, tree(4), tree(count))
    }
  }

  @Test
  fun inheritedMarkerOffsetsFollowTheRtlDirection() {
    val style = styleConfig()
    val text = SpannableString(render(document(withChild(numbered(1000), 0, numbered(1))), style))
    val layout =
      StaticLayout.Builder
        .obtain(text, 0, text.length, TextPaint(), LAYOUT_WIDTH)
        .setTextDirection(TextDirectionHeuristics.RTL)
        .build()
    val canvas = MarkerCanvas()
    layout.draw(canvas)
    assertEquals(1001, canvas.markers.size)
    canvas.markers.forEach { marker ->
      val line = layout.getLineForVertical(marker.baseline.toInt())
      assertEquals(-1, layout.getParagraphDirection(line))
      assertEquals(layout.getParagraphRight(line) + style.listStyle.gapWidth, marker.left, 0.01f)
      assertTrue(marker.right <= layout.width)
    }
  }

  private fun assertNestedMarkerGapsUnchanged(
    style: StyleConfig,
    short: MarkdownASTNode,
    wide: MarkdownASTNode,
  ) {
    val shortMarkers = drawMarkers(style, short).filter { it.depth > 0 }
    val wideMarkers = drawMarkers(style, wide).filter { it.depth > 0 }
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
    style: StyleConfig,
    vararg lists: MarkdownASTNode,
  ): List<MarkerGeometry> {
    // SpannableString reports spans in insertion order, as the text view does.
    val text = SpannableString(render(document(*lists), style))
    val paint = TextPaint().apply { textSize = style.listStyle.fontSize }
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, LAYOUT_WIDTH).build()
    val canvas = MarkerCanvas()
    layout.draw(canvas)
    assertEquals(text.getSpans(0, text.length, BaseListSpan::class.java).size, canvas.markers.size)
    return canvas.markers.map { marker ->
      val line = layout.getLineForVertical(marker.baseline.toInt())
      assertTrue("marker left ${marker.left} on line $line", marker.left >= 0f)
      val start = layout.getLineStart(line)
      val depth = text.getSpans(start, start + 1, BaseListSpan::class.java).maxOf { it.depth }
      MarkerGeometry(marker, layout.getParagraphLeft(line).toFloat(), depth)
    }
  }

  private fun orderedSpans(
    style: StyleConfig,
    vararg lists: MarkdownASTNode,
  ): List<OrderedListSpan> {
    val text = render(document(*lists), style)
    return text
      .getSpans(0, text.length, OrderedListSpan::class.java)
      .sortedWith(compareBy({ text.getSpanStart(it) }, { it.depth }))
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

  private class MarkerCanvas : Canvas(Bitmap.createBitmap(LAYOUT_WIDTH, 1, Bitmap.Config.ARGB_8888)) {
    val markers = mutableListOf<DrawnMarker>()

    // Layout draws only the lines inside the clip; report a clip tall enough for every list here.
    override fun getClipBounds(bounds: Rect): Boolean {
      bounds.set(0, 0, LAYOUT_WIDTH, Int.MAX_VALUE / 2)
      return true
    }

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
      rect: RectF,
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

  private fun item(): MarkdownASTNode = listItem(paragraph(text("item")))

  private fun numbered(count: Int): MarkdownASTNode = orderedList(*Array(count) { item() })

  private fun withChild(
    list: MarkdownASTNode,
    index: Int,
    child: MarkdownASTNode,
  ): MarkdownASTNode {
    val items = list.children.toMutableList()
    items[index] = items[index].copy(children = items[index].children + child)
    return list.copy(children = items)
  }

  private fun styleConfig(minWidth: Float = 0f): StyleConfig {
    val base = MarkdownRenderTestSupport.defaultStyle
    return MarkdownRenderTestSupport.styleWithList(
      base.listStyle.copy(
        fontFamily = "monospace",
        markerMinWidth = minWidth,
        gapWidth = 8f,
        marginLeft = 24f,
      ),
    )
  }

  private companion object {
    const val LAYOUT_WIDTH = 2000
  }
}
