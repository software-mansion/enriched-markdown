package com.swmansion.enriched.markdown

import android.graphics.Typeface
import android.text.SpannableString
import android.text.StaticLayout
import android.text.TextPaint
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.BaseListSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkerCanvas
import com.swmansion.enriched.markdown.test.MarkerGeometry
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
import kotlin.math.ceil

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ListRenderingTest {
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
      spans.forEach { assertEquals((baseline + ceil(widest - baseline) + gap).toInt(), it.getLeadingMargin(false)) }
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
  fun orderedListsCountFromTheirStartNumber() {
    val style = styleConfig()
    assertEquals(listOf(3, 4), orderedSpans(style, orderedList(3, item(), item())).map { it.itemNumber })
    assertEquals(listOf(0, 1), orderedSpans(style, orderedList(0, item(), item())).map { it.itemNumber })
  }

  @Test
  fun startNumbersFrom100WidenTheGutter() {
    val style = styleConfig()
    val paint =
      TextPaint().apply {
        textSize = style.listStyle.fontSize
        typeface = Typeface.create("monospace", Typeface.NORMAL)
      }
    val baseline = paint.measureText("99.")
    val gap = style.listStyle.gapWidth
    val belowHundred = orderedSpans(style, orderedList(97, item(), item(), item()))
    assertEquals(listOf(97, 98, 99), belowHundred.map { it.itemNumber })
    belowHundred.forEach { assertEquals((baseline + gap).toInt(), it.getLeadingMargin(false)) }
    val crossing = orderedSpans(style, orderedList(98, item(), item(), item()))
    assertEquals(listOf(98, 99, 100), crossing.map { it.itemNumber })
    val widened = (baseline + ceil(paint.measureText("100.") - baseline) + gap).toInt()
    crossing.forEach { assertEquals(widened, it.getLeadingMargin(false)) }
  }

  @Test
  fun nestedOrderedListsKeepTheirOwnStartNumbers() {
    val style = styleConfig()
    val outer =
      orderedList(
        5,
        listItem(paragraph(text("item")), orderedList(10, item(), item())),
        listItem(paragraph(text("item")), numbered(2)),
        item(),
      )
    val numbers = orderedSpans(style, outer, numbered(1)).map { it.depth to it.itemNumber }
    assertEquals(listOf(0 to 5, 1 to 10, 1 to 11, 0 to 6, 1 to 1, 1 to 2, 0 to 7, 0 to 1), numbers)
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
  fun tasksMoveWithTheirWideNumberedSiblings() {
    val style = styleConfig()

    fun tree(count: Int): MarkdownASTNode {
      val items = numbered(count).children.toMutableList()
      items[1] = taskListItem(checked = false, paragraph(text("task")), numbered(1))
      items[2] = listItem(paragraph(text("item")), numbered(1))
      return orderedList(*items.toTypedArray())
    }
    assertEveryRowShiftsTogether(style, tree(4), tree(1000))
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
    val layout = MarkerCanvas.layout(text, style.listStyle.fontSize, rtl = true)
    val markers = MarkerCanvas.drawMarkers(layout)
    assertEquals(1001, markers.size)
    markers.forEach { marker ->
      val line = layout.getLineForVertical(marker.baseline.toInt())
      assertEquals(-1, layout.getParagraphDirection(line))
      assertEquals(layout.getParagraphRight(line) + style.listStyle.gapWidth, marker.left, 0.01f)
      assertTrue(marker.right <= layout.width)
    }
  }

  @Test
  fun mixedNestsStartTheirTextFromTheirOwnMarkerColumn() {
    val style = mixedStyle()
    for (parent in Kind.entries) {
      for (child in Kind.entries.filter { it != parent }) {
        for (checked in checkedStates(parent, child)) {
          val markers = drawMarkers(style, list(parent, list(child, checked = checked), checked))
          assertEquals(listOf(0, 1), markers.map { it.depth })
          val expected = (24f + columnOf(style, child) + MIXED_GAP).toInt().toFloat()
          assertEquals("$child under $parent", expected, markers.last().paragraphLeft, 0f)
          assertMixedGaps(markers, "$child under $parent, checked=$checked")
        }
      }
    }
  }

  @Test
  fun topLevelAndSameTypeNestsKeepTheirGeometry() {
    val style = mixedStyle()
    for (kind in Kind.entries) {
      val column = columnOf(style, kind)
      val markers = drawMarkers(style, list(kind, list(kind, list(kind))))
      assertEquals(listOf(0, 1, 2), markers.map { it.depth })
      markers.forEach {
        assertEquals("text for $kind at depth ${it.depth}", (column + MIXED_GAP).toInt() + it.depth * 24f, it.paragraphLeft, 0f)
        assertEquals(column + it.depth * 24f, it.marker.right, 0.01f)
      }
    }
  }

  @Test
  fun mixedColumnsUseAbsoluteIndentsWithoutFractionalDrift() {
    val alternating = listOf(Kind.BULLET, Kind.ORDERED, Kind.BULLET, Kind.TASK)
    val sameTypeRun = List(5) { Kind.BULLET } + Kind.TASK
    for (margin in listOf(24f, 24.5f, 4f)) {
      val style = mixedStyle(bulletSize = 6.5f, marginLeft = margin)
      for (kinds in listOf(alternating, sameTypeRun)) {
        val columns = kinds.map { columnOf(style, it) }
        val tree = kinds.dropLast(1).foldRight(list(kinds.last())) { kind, child -> list(kind, child) }
        val markers = drawMarkers(style, tree)
        assertEquals(kinds.indices.toList(), markers.map { it.depth })
        markers.forEach {
          val expected = (it.depth * margin + columns[it.depth] + MIXED_GAP).toInt().toFloat()
          assertEquals("absolute indent at depth ${it.depth} of $kinds, margin $margin", expected, it.paragraphLeft, 0f)
          assertEquals(it.paragraphLeft - MIXED_GAP, it.marker.right, 0.99f)
        }
      }
    }
  }

  @Test
  fun mixedAncestorsAndFollowingSiblingsRestoreTheirOwnColumns() {
    val style = mixedStyle()
    for (parent in Kind.entries) {
      val tree = list(parent).copy(children = Kind.entries.map { child -> item(parent, list(child, list(parent))) })
      assertMixedGaps(drawMarkers(style, tree, list(Kind.BULLET), list(Kind.ORDERED), list(Kind.TASK)), "under $parent")
    }
  }

  @Test
  fun mixedNestsAroundWideNumberedListsKeepTheirMarkerGap() {
    val style = mixedStyle()
    val wide = numbered(101)
    val wideWithTask = withChild(numbered(101), 1, list(Kind.TASK, list(Kind.BULLET)))
    val shapes =
      listOf(
        withChild(wide, 0, list(Kind.BULLET)),
        wideWithTask,
        list(Kind.BULLET, wide),
        list(Kind.TASK, wide),
        withChild(numbered(1000), 999, withChild(wide, 0, list(Kind.BULLET))),
        list(Kind.BULLET, withChild(wide, 1, list(Kind.TASK))),
        orderedList(*numbered(101).children.toTypedArray(), item(Kind.TASK, list(Kind.BULLET))),
      )
    for ((index, shape) in shapes.withIndex()) {
      assertMixedGaps(drawMarkers(style, shape), "shape $index")
    }
  }

  @Test
  fun wrappedLinesKeepTheChildsOwnColumn() {
    val style = mixedStyle()
    val wrapped = orderedList(listItem(paragraph(text("wrapped child text ".repeat(12)))))
    val text = SpannableString(render(document(list(Kind.BULLET, wrapped)), style))
    val layout = StaticLayout.Builder.obtain(text, 0, text.length, TextPaint(), 180).build()
    val span = text.getSpans(0, text.length, OrderedListSpan::class.java).single()
    val firstLine = layout.getLineForOffset(text.getSpanStart(span))
    val lastLine = layout.getLineForOffset(text.getSpanEnd(span) - 1)
    assertTrue(lastLine > firstLine)
    val column = columnOf(style, Kind.ORDERED)
    for (line in firstLine..lastLine) {
      assertEquals((24f + column + MIXED_GAP).toInt(), layout.getParagraphLeft(line))
    }
    val markers = MarkerCanvas.drawMarkers(layout)
    assertEquals(2, markers.size)
    assertEquals(24f + column, markers.last().right, 0.01f)
  }

  @Test
  fun rtlMixedNestsKeepTheirMarkerGapAtEveryDepth() {
    fun rtl(node: MarkdownASTNode): MarkdownASTNode {
      if (node.type == MarkdownASTNode.NodeType.Text) return node.copy(content = "\u05e4\u05e8\u05d9\u05d8")
      return node.copy(children = node.children.map { rtl(it) })
    }

    val style = mixedStyle()
    for (parent in Kind.entries) {
      for (child in Kind.entries.filter { it != parent }) {
        for (checked in checkedStates(parent, child)) {
          val tree = list(parent, list(child, list(parent, checked = checked), checked), checked)
          val text = SpannableString(render(document(rtl(tree)), style))
          val markers = MarkerCanvas.markerGeometry(text, MarkerCanvas.layout(text, style.listStyle.fontSize, rtl = true))
          assertEquals(listOf(0, 1, 2), markers.map { it.depth })
          markers.forEach {
            assertEquals("RTL paragraph at depth ${it.depth}", -1, it.direction)
            // Bullets are centered on the column edge, so their recorded right is that edge in both directions.
            val kind = if (it.depth == 1) child else parent
            val edge = if (kind == Kind.BULLET) it.marker.right else it.marker.left
            assertEquals("$child under $parent, checked=$checked, depth ${it.depth}", it.paragraphRight + MIXED_GAP, edge, 0.01f)
          }
        }
      }
    }
  }

  @Test
  fun equalMinimumColumnsKeepTheirGeometryForMixedNests() {
    val style = mixedStyle(markerMinWidth = 40f)
    for (parent in Kind.entries) {
      for (child in Kind.entries.filter { it != parent }) {
        val markers = drawMarkers(style, list(parent, list(child, list(parent))))
        assertEquals(listOf(0, 1, 2), markers.map { it.depth })
        markers.forEach {
          assertEquals("text for $child under $parent at depth ${it.depth}", 46f + it.depth * 24f, it.paragraphLeft, 0f)
          assertEquals(40f + it.depth * 24f, it.marker.right, 0.01f)
        }
      }
    }
  }

  /** The rows [wide] shares with [short], tasks and their children included, all sit [wide]'s widening further right. */
  private fun assertEveryRowShiftsTogether(
    style: StyleConfig,
    short: MarkdownASTNode,
    wide: MarkdownASTNode,
  ) {
    val shortRows = drawMarkers(style, short)
    val wideRows = drawMarkers(style, wide).take(shortRows.size)
    assertEquals(shortRows.size, wideRows.size)
    val shift = wideRows.first().paragraphLeft - shortRows.first().paragraphLeft
    assertTrue(shift > 0f)
    wideRows.zip(shortRows).forEach { (actual, control) ->
      assertEquals(control.depth, actual.depth)
      assertEquals("text shift at depth ${actual.depth}", shift, actual.paragraphLeft - control.paragraphLeft, 0.01f)
      assertEquals(
        "marker gap at depth ${actual.depth}",
        control.paragraphLeft - control.marker.right,
        actual.paragraphLeft - actual.marker.right,
        0.01f,
      )
    }
  }

  private fun assertMixedGaps(
    markers: List<MarkerGeometry>,
    shape: String,
  ) {
    assertTrue(markers.isNotEmpty())
    markers.forEach {
      assertEquals("marker gap at depth ${it.depth}, $shape", it.paragraphLeft - MIXED_GAP, it.marker.right, 0.01f)
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
    val geometry = MarkerCanvas.markerGeometry(text, MarkerCanvas.layout(text, style.listStyle.fontSize))
    assertEquals(text.getSpans(0, text.length, BaseListSpan::class.java).size, geometry.size)
    geometry.forEach { assertTrue("marker left ${it.marker.left} at depth ${it.depth}", it.marker.left >= 0f) }
    return geometry
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

  private enum class Kind { ORDERED, BULLET, TASK }

  private fun list(
    kind: Kind,
    child: MarkdownASTNode? = null,
    checked: Boolean = false,
  ): MarkdownASTNode {
    val item = item(kind, child, checked)
    return if (kind == Kind.ORDERED) orderedList(item) else unorderedList(item)
  }

  private fun item(
    kind: Kind,
    child: MarkdownASTNode? = null,
    checked: Boolean = false,
  ): MarkdownASTNode {
    val children = listOfNotNull(paragraph(text("item")), child).toTypedArray()
    return if (kind == Kind.TASK) taskListItem(checked, *children) else listItem(*children)
  }

  private fun checkedStates(
    parent: Kind,
    child: Kind,
  ) = if (parent == Kind.TASK || child == Kind.TASK) listOf(false, true) else listOf(false)

  /** The marker column [kind] reserves before any widening, read from a rendered top-level item. */
  private fun columnOf(
    style: StyleConfig,
    kind: Kind,
  ): Float {
    val text = render(document(list(kind)), style)
    return text.getSpans(0, text.length, BaseListSpan::class.java).single().baselineMarkerWidth
  }

  private fun mixedStyle(
    markerMinWidth: Float = 0f,
    bulletSize: Float = 6f,
    marginLeft: Float = 24f,
  ): StyleConfig {
    val base = MarkdownRenderTestSupport.defaultStyle
    return MarkdownRenderTestSupport.styleWithList(
      base.listStyle.copy(
        fontSize = 16f,
        bulletSize = bulletSize,
        markerMinWidth = markerMinWidth,
        gapWidth = MIXED_GAP,
        marginLeft = marginLeft,
      ),
      base.taskListStyle.copy(checkboxSize = 14f),
    )
  }

  private companion object {
    const val MIXED_GAP = 6f
  }
}
