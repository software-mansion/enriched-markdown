package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// #1072: inside a list item a code block's box starts at the item's indent, which the layout puts on
// the right of a right-to-left code paragraph: the box has to leave the indent there, not on the left.
// It takes the side of the block's first line for all its lines, and holds every line's text.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CodeBlockSpanDirectionTest {
  private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 40f }

  // The filled shapes a draw paints, in the layout's coordinates.
  private class Recorder : Canvas(Bitmap.createBitmap(WIDTH, 2000, Bitmap.Config.ARGB_8888)) {
    val fills = mutableListOf<RectF>()

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      @Suppress("DEPRECATION")
      if (paint.style == Paint.Style.FILL) fills.add(RectF().also { path.computeBounds(it, true) }.also(matrix::mapRect))
    }
  }

  @Test
  fun aRightToLeftCodeBlockInAListItemLeavesTheIndentOnTheRight() {
    val leftToRight = codeBoxes("item", "first line\nsecond line\n")
    val rightToLeft = codeBoxes("עברית", "שורה ראשונה\nשורה שנייה\n")

    assertTrue("left to right: indented on the left", leftToRight.first().left > 5f)
    for (box in rightToLeft) {
      assertEquals("mirrors the left-to-right box", WIDTH - leftToRight.first().right, box.left, 1f)
      assertEquals("mirrors the left-to-right box", WIDTH - leftToRight.first().left, box.right, 1f)
    }
  }

  // A line in the other direction, a lone brace or a blank line keeps the box a rectangle.
  @Test
  fun aCodeBlockWithLinesInBothDirectionsKeepsOneBox() {
    val leftToRight = codeBoxes("item", "first line\nsecond line\n")
    val mixed = codeBoxes("item", "let a = 1\n// הערה\nlet b = 2\n")
    val rightToLeft = codeBoxes("עברית", "שורה ראשונה\n}\n\nשורה שנייה\n")

    for (box in mixed) assertSameSides(leftToRight.first(), box)
    for (box in rightToLeft) assertSameSides(rightToLeft.first(), box)
    assertEquals(WIDTH - leftToRight.first().right, rightToLeft.first().left, 1f)
  }

  // ASCII code in a right-to-left item is laid out left to right, so its box is too: one that
  // followed the item instead would end short of a line that runs to the edge.
  @Test
  fun asciiCodeInARightToLeftItemKeepsALeftToRightBox() {
    assertSameSides(codeBoxes("item", "let a = 1\n").first(), codeBoxes("עברית", "let a = 1\n").first())
  }

  // Long lines that wrap to the far edge, in nested items so the indent is wider than a line's slack.
  // Not covered: in a block that mixes directions, a long line in the other direction than the first
  // still runs past the box by the indent; only a box under the list marker could hold it.
  @Test
  fun everyLineOfCodeStaysInsideTheBox() {
    // No spaces: the line breaks inside the token and fills to the edge, with no slack to hide in.
    val ascii = "x".repeat(400)
    val hebrew = "ש".repeat(400)
    for ((item, code) in listOf("item" to "$ascii\n", "עברית" to "$ascii\nשורה\n", "עברית" to "$hebrew\n")) {
      val text = render(styleConfig(), nested(item, code))
      val layout = layoutOf(text)
      val boxes = strips(text, layout)
      val span = text.getSpans(0, text.length, CodeBlockSpan::class.java).single()
      val first = layout.getLineForOffset(text.getSpanStart(span))
      val last = layout.getLineForOffset(text.getSpanEnd(span) - 1)
      for (line in first..last) {
        // Where the line's glyphs are: from where it starts to its far edge, rightward or leftward.
        if (layout.getLineVisibleEnd(line) <= layout.getLineStart(line)) continue
        val a = layout.getPrimaryHorizontal(layout.getLineStart(line))
        val b = if (layout.getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT) layout.getLineLeft(line) else layout.getLineRight(line)
        val box = boxes.single { it.top <= layout.getLineTop(line) + 1 && it.bottom >= layout.getLineBottom(line) - 1 }
        assertTrue("line $line of \"$code\": ${minOf(a, b)} < ${box.left}", minOf(a, b) >= box.left - 0.5f)
        assertTrue("line $line of \"$code\": ${maxOf(a, b)} > ${box.right}", maxOf(a, b) <= box.right + 0.5f)
      }
    }
  }

  private fun assertSameSides(
    expected: RectF,
    actual: RectF,
  ) {
    assertEquals(expected.left, actual.left, 0.5f)
    assertEquals(expected.right, actual.right, 0.5f)
  }

  // The code block's box strips, drawn as the view draws: text backgrounds, then the layout.
  private fun codeBoxes(
    item: String,
    code: String,
  ): List<RectF> {
    val text = render(styleConfig(), unorderedList(listItem(paragraph(text(item)), codeBlock(code))))
    return strips(text, layoutOf(text))
  }

  // Two levels deep, so the indent is wider than a line's slack.
  private fun nested(
    item: String,
    code: String,
  ): MarkdownASTNode = unorderedList(listItem(paragraph(text(item)), unorderedList(listItem(paragraph(text(item)), codeBlock(code)))))

  private fun codeBlock(code: String) = MarkdownASTNode(NodeType.CodeBlock, children = listOf(text(code)))

  private fun layoutOf(text: CharSequence): StaticLayout =
    StaticLayout.Builder
      .obtain(text, 0, text.length, paint, WIDTH)
      .setTextDirection(TextDirectionHeuristics.FIRSTSTRONG_LTR)
      .setAlignment(Layout.Alignment.ALIGN_NORMAL)
      .build()

  private fun strips(
    text: CharSequence,
    layout: Layout,
  ): List<RectF> {
    val recorder = Recorder()
    TextBackgroundDrawer().draw(recorder, layout, text, 0f, 0f)
    layout.draw(recorder)
    val boxes = recorder.fills.filter { it.width() > WIDTH / 2 }
    assertTrue("a box for the code", boxes.isNotEmpty())
    return boxes
  }

  private companion object {
    const val WIDTH = 1200
  }
}
