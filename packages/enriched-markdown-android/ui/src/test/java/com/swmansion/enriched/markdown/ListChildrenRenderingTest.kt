package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.text.Layout
import android.text.SpannableString
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.CodeBlockSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TaskListStyle
import com.swmansion.enriched.markdown.test.DrawnMarker
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkerCanvas
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Block children of list items: code blocks, sublists and quotes inside an item. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class ListChildrenRenderingTest {
  @Test
  fun codeBlockEndingAnItemKeepsItsBottomPaddingAndCorners() {
    val drawn = draw(itemsWithCode(codeBlock(CODE)))

    // The first line carries the top padding and the last the bottom one, so they match.
    assertEquals("bottom padding of the last code line", drawn.height("first line"), drawn.height("last line"))
    assertFalse("the last code line rounds its bottom corners", drawn.codeBoxOn("last line").isRect)
  }

  @Test
  fun codeBlockInsideAnItemStartsAtTheItemsTextColumn() {
    val drawn = draw(itemsWithCode(codeBlock(CODE)))
    val itemColumn = drawn.textLeft("Item")

    assertTrue(itemColumn > 0f)
    for (line in listOf("first line", "last line")) {
      assertEquals("code box left on \"$line\"", itemColumn, drawn.codeBoxOn(line).bounds.left, 0.01f)
      assertEquals("code text left on \"$line\"", itemColumn + CODE_PADDING, drawn.textLeft(line), 0.01f)
    }
  }

  @Test
  fun blockquoteInsideAnItemKeepsTheMarkersAndIndent() {
    val drawn =
      draw(
        unorderedList(
          listItem(paragraph(text("Item")), blockquote(paragraph(text("Quoted")))),
          listItem(paragraph(text("Next"))),
        ),
      )

    assertEquals(listOf(drawn.line("Item"), drawn.line("Next")), drawn.markers.map { drawn.lineOf(it) })
    assertTrue(drawn.textLeft("Quoted") > drawn.textLeft("Item"))
    assertEquals(drawn.quoteBarsOn("Quoted"), drawn.quoteBarsOn("Quoted").distinct())
  }

  @Test
  fun codeBlockInAQuoteUnderANestedBulletKeepsTheQuoteAndMarkers() {
    // 1. Ordered
    //    - Bullet
    //      > ```
    //      > first line
    //      > last line
    //      > ```
    //    - Another bullet
    val drawn =
      draw(
        orderedList(
          listItem(
            paragraph(text("Ordered")),
            unorderedList(
              listItem(paragraph(text("Bullet")), blockquote(codeBlock(CODE))),
              listItem(paragraph(text("Another bullet"))),
            ),
          ),
        ),
      )

    assertEquals(
      listOf(drawn.line("Ordered"), drawn.line("Bullet"), drawn.line("Another bullet")),
      drawn.markers.map { drawn.lineOf(it) },
    )
    val bar = drawn.quoteBarsOn("first line")
    assertTrue("the quote draws its bar beside the code", bar.isNotEmpty())
    assertEquals("the quote bar stays put across the code lines", bar, drawn.quoteBarsOn("last line"))
    assertEquals(drawn.textLeft("first line"), drawn.textLeft("last line"), 0.01f)
    assertTrue(drawn.textLeft("first line") > drawn.textLeft("Bullet"))
    assertEquals("bottom padding of the last code line", drawn.height("first line"), drawn.height("last line"))
    assertFalse(drawn.codeBoxOn("last line").isRect)
    assertEquals("the next bullet keeps its column", drawn.textLeft("Bullet"), drawn.textLeft("Another bullet"), 0.01f)
  }

  @Test
  fun checkedTaskWithACodeBlockDrawsOneCheckboxAndLeavesTheCodeUndecorated() {
    val style =
      style(
        taskListStyle =
          MarkdownRenderTestSupport.defaultTaskListStyle().copy(
            checkedTextColor = CHECKED_TEXT_COLOR,
            checkedStrikethrough = true,
          ),
      )
    val drawn =
      draw(
        unorderedList(
          taskListItem(checked = true, paragraph(text("Done")), codeBlock(CODE), paragraph(text("After code"))),
          taskListItem(checked = false, paragraph(text("Next"))),
        ),
        style,
      )

    assertEquals(listOf(drawn.line("Done"), drawn.line("Next")), drawn.markers.map { drawn.lineOf(it) })
    assertEquals("bottom padding of the last code line", drawn.height("first line"), drawn.height("last line"))
    assertEquals(drawn.textLeft("Done"), drawn.codeBoxOn("first line").bounds.left, 0.01f)

    val text = drawn.text
    val code = text.getSpans(0, text.length, CodeBlockSpan::class.java).single()
    val codeStart = text.getSpanStart(code)
    val codeEnd = text.getSpanEnd(code)
    assertTrue(text.getSpans(codeStart, codeEnd, StrikethroughSpan::class.java).isEmpty())
    assertTrue(text.getSpans(codeStart, codeEnd, ForegroundColorSpan::class.java).none { it.foregroundColor == CHECKED_TEXT_COLOR })
    for (decorated in listOf("Done", "After code")) {
      val start = text.indexOf(decorated)
      assertTrue("\"$decorated\" is struck through", text.getSpans(start, start + 1, StrikethroughSpan::class.java).isNotEmpty())
    }
  }

  private fun itemsWithCode(code: MarkdownASTNode): MarkdownASTNode =
    unorderedList(
      listItem(paragraph(text("Item")), code),
      listItem(paragraph(text("Next"))),
      listItem(paragraph(text("Last"))),
    )

  private fun draw(
    block: MarkdownASTNode,
    style: StyleConfig = style(),
  ): Drawn {
    // SpannableString reports spans in priority and insertion order, as the text view does.
    val text = SpannableString(render(document(block), style))
    val layout = MarkerCanvas.layout(text, style.listStyle.fontSize)
    val blocks = BlockCanvas().also(layout::draw)
    val markers = MarkerCanvas.drawMarkers(layout, ignoredColors = setOf(QUOTE_BORDER, CHECKED_TEXT_COLOR))
    return Drawn(text, layout, markers, blocks.codeBoxes, blocks.quoteBars)
  }

  private fun style(taskListStyle: TaskListStyle? = null): StyleConfig {
    val base = MarkdownRenderTestSupport.defaultStyle
    return MarkdownRenderTestSupport.styleWithListAndCodeBlock(
      listStyle = base.listStyle.copy(lineHeight = 0f, gapWidth = 8f, marginLeft = 24f),
      codeBlockStyle =
        base.codeBlockStyle.copy(
          backgroundColor = CODE_BACKGROUND,
          borderWidth = 0f,
          borderRadius = 6f,
          padding = CODE_PADDING,
          marginTop = 8f,
          marginBottom = 8f,
        ),
      taskListStyle = taskListStyle,
      blockquoteStyle = base.blockquoteStyle.copy(borderColor = QUOTE_BORDER, borderWidth = 3f, gapWidth = 10f, backgroundColor = null),
    )
  }

  private class CodeBox(
    val bounds: RectF,
    val isRect: Boolean,
  )

  private class Drawn(
    val text: Spanned,
    val layout: Layout,
    val markers: List<DrawnMarker>,
    val codeBoxes: List<CodeBox>,
    val quoteBars: List<RectF>,
  ) {
    fun line(content: String): Int {
      val start = text.indexOf(content)
      require(start >= 0) { "Rendered text does not contain \"$content\": \"$text\"" }
      return layout.getLineForOffset(start)
    }

    fun lineOf(marker: DrawnMarker): Int = layout.getLineForVertical(marker.baseline.toInt())

    fun height(content: String): Int = line(content).let { layout.getLineBottom(it) - layout.getLineTop(it) }

    fun textLeft(content: String): Float = layout.getParagraphLeft(line(content)).toFloat()

    fun codeBoxOn(content: String): CodeBox {
      val line = line(content)
      return codeBoxes.single { it.bounds.centerY() > layout.getLineTop(line) && it.bounds.centerY() < layout.getLineBottom(line) }
    }

    /** The left edges of the quote bars drawn on [content]'s line. */
    fun quoteBarsOn(content: String): List<Float> {
      val line = line(content)
      return quoteBars
        .filter { it.centerY() > layout.getLineTop(line) && it.centerY() < layout.getLineBottom(line) }
        .map { it.left }
        .sorted()
    }
  }

  /** Records the code block boxes and blockquote bars a layout draws. */
  private class BlockCanvas : Canvas(Bitmap.createBitmap(MarkerCanvas.LAYOUT_WIDTH, 1, Bitmap.Config.ARGB_8888)) {
    val codeBoxes = mutableListOf<CodeBox>()
    val quoteBars = mutableListOf<RectF>()

    override fun getClipBounds(bounds: Rect): Boolean {
      bounds.set(0, 0, MarkerCanvas.LAYOUT_WIDTH, Int.MAX_VALUE / 2)
      return true
    }

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      if (paint.color == CODE_BACKGROUND && paint.style == Paint.Style.FILL) {
        val bounds = RectF()
        path.computeBounds(bounds, true)
        codeBoxes += CodeBox(bounds, path.isRect(RectF()))
      }
      super.drawPath(path, paint)
    }

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      if (paint.color == QUOTE_BORDER) quoteBars += RectF(left, top, right, bottom)
      super.drawRect(left, top, right, bottom, paint)
    }
  }

  private companion object {
    const val CODE = "first line\nlast line\n"
    const val CODE_PADDING = 12f
    const val CODE_BACKGROUND = 0xFF123456.toInt()
    const val QUOTE_BORDER = 0xFF654321.toInt()
    const val CHECKED_TEXT_COLOR = 0xFF9E9E9E.toInt()
  }
}
