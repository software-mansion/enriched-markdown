package com.swmansion.enriched.markdown.spans

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.DynamicLayout
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.ReplacementSpan
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// Inline code backgrounds come from the layout that draws the text, so they sit under the glyphs
// whatever the alignment or direction.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TextBackgroundDrawerTest {
  private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 40f }

  // The filled shapes a draw paints, as bounds in the layout's coordinates.
  private class Recorder : Canvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888)) {
    val fills = mutableListOf<RectF>()

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      @Suppress("DEPRECATION")
      if (paint.style == Paint.Style.FILL) fills.add(RectF().also { path.computeBounds(it, true) }.also(matrix::mapRect))
    }
  }

  private fun layout(
    text: CharSequence,
    width: Int = 1600,
    alignment: Layout.Alignment = Layout.Alignment.ALIGN_NORMAL,
    rightToLeft: Boolean = false,
  ): StaticLayout =
    StaticLayout.Builder
      .obtain(text, 0, text.length, paint, width)
      .setAlignment(alignment)
      .setTextDirection(if (rightToLeft) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
      .build()

  private fun withCode(
    text: String,
    start: Int,
    end: Int,
  ) = SpannableStringBuilder(text).apply { setSpan(CodeBackgroundSpan(styleConfig()), start, end, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE) }

  private fun draw(
    layout: Layout,
    drawer: TextBackgroundDrawer = TextBackgroundDrawer(),
  ): List<RectF> = Recorder().also { drawer.draw(it, layout, layout.text, 0f, 0f) }.fills

  private fun assertCovers(
    layout: Layout,
    start: Int,
    end: Int,
    rect: RectF,
  ) {
    val a = layout.getPrimaryHorizontal(start)
    val b = layout.getPrimaryHorizontal(end)
    assertEquals(minOf(a, b), rect.left, 0.5f)
    assertEquals(maxOf(a, b), rect.right, 0.5f)
  }

  @Test
  fun aSpanSitsUnderItsGlyphs() {
    val text = withCode("Call fetch() and wait", 5, 12)
    val layout = layout(text)
    val fills = draw(layout)
    assertEquals(1, fills.size)
    assertCovers(layout, 5, 12, fills[0])
  }

  @Test
  fun aCenteredOrRightToLeftLineKeepsItUnderItsGlyphs() {
    val centered = layout(withCode("Call fetch() and wait", 5, 12), alignment = Layout.Alignment.ALIGN_CENTER)
    val fills = draw(centered)
    assertCovers(centered, 5, 12, fills.single())
    assertTrue(fills.single().left > 200f)

    val rightToLeft = layout(withCode("שלום fetch() עולם", 5, 12), rightToLeft = true)
    assertCovers(rightToLeft, 5, 12, draw(rightToLeft).single())
  }

  @Test
  fun aWrappedSpanRunsToTheLineEdges() {
    val text = withCode("aaaa bbbb cccc dddd eeee ffff gggg", 10, 24)
    val layout = layout(text, width = 260)
    val first = layout.getLineForOffset(10)
    val last = layout.getLineForOffset(23)
    assertTrue(last > first)
    val fills = draw(layout)
    assertEquals(last - first + 1, fills.size)
    assertEquals(layout.getPrimaryHorizontal(10), fills.first().left, 0.5f)
    assertEquals(layout.getLineRight(first), fills.first().right, 0.5f)
    assertEquals(layout.getPrimaryHorizontal(layout.getLineStart(last)), fills.last().left, 0.5f)
    assertEquals(layout.getPrimaryHorizontal(24), fills.last().right, 0.5f)
  }

  // The layout's line edges ignore leading margins in some alignments and Android versions.
  @Test
  @Config(sdk = [28, 30])
  fun aWrappedSpanInsideALeadingMarginCoversEachLinesGlyphs() {
    for (rightToLeft in listOf(false, true)) {
      val text = withCode("fetch() aaaa bbbb cccc dddd eeee", 0, 32)
      text.setSpan(LeadingMarginSpan.Standard(80), 0, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      val layout = layout(text, width = 340, rightToLeft = rightToLeft)
      val fills = draw(layout)
      assertTrue(fills.size > 1)
      fills.forEachIndexed { line, fill ->
        val glyphs = glyphBounds(layout, line)
        assertEquals("rtl=$rightToLeft line $line", glyphs.left, fill.left, 0.5f)
        assertEquals("rtl=$rightToLeft line $line", glyphs.right, fill.right, 0.5f)
      }
    }
  }

  // Where [line]'s glyphs are, read from the layout's selection, without trailing spaces.
  private fun glyphBounds(
    layout: Layout,
    line: Int,
  ): RectF {
    var end = layout.getLineEnd(line)
    while (end > layout.getLineStart(line) && layout.text[end - 1].isWhitespace()) end--
    val path = Path()
    layout.getSelectionPath(layout.getLineStart(line), end, path)
    return RectF().also { path.computeBounds(it, true) }
  }

  @Test
  fun aViewDrawsAtItsPaddingAndNotPastItsTextBox() {
    val view = TextView(RuntimeEnvironment.getApplication())
    view.setTextSize(TypedValue.COMPLEX_UNIT_PX, 40f)
    view.includeFontPadding = false
    view.setPadding(30, 20, 30, 50)
    view.text =
      withCode("Call fetch() and\nmore\nthen `hidden` here", 5, 12).apply {
        setSpan(CodeBackgroundSpan(styleConfig()), length - 13, length - 5, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    view.measure(View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.EXACTLY), View.MeasureSpec.UNSPECIFIED)
    val twoLines = view.layout.getLineTop(2) + 20 + 50
    view.measure(
      View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(twoLines, View.MeasureSpec.EXACTLY),
    )
    view.layout(0, 0, 1000, twoLines)

    val recorder = Recorder()
    TextBackgroundDrawer().draw(recorder, view)
    val fill = recorder.fills.single()
    assertEquals(30f + view.layout.getPrimaryHorizontal(5), fill.left, 0.5f)
    assertEquals(20f + view.layout.getLineTop(0), fill.top, 0.5f)
  }

  @Test
  fun aQuoteFillDrawsUnderItsInlineCode() {
    val quote =
      MarkdownASTNode(
        NodeType.Blockquote,
        children = listOf(paragraph(text("use "), MarkdownASTNode(NodeType.Code, children = listOf(text("fetch()"))))),
      )
    val text = render(styleConfig(blockquote = mapOf("backgroundColor" to Color.RED)), quote)
    val layout = layout(text)
    val recorder = OrderRecorder()
    TextBackgroundDrawer().draw(recorder, layout, text, 0f, 0f)
    val code = styleConfig().codeStyle.backgroundColor
    assertEquals(listOf(Color.RED, code), recorder.colors.distinct())
  }

  // The colors of the shapes a draw fills, in the order it fills them, and the rectangles among them.
  private class OrderRecorder : Canvas(Bitmap.createBitmap(2000, 2000, Bitmap.Config.ARGB_8888)) {
    val colors = mutableListOf<Int>()
    val rects = mutableListOf<RectF>()

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      if (paint.style == Paint.Style.FILL) {
        colors.add(paint.color)
        rects.add(RectF(left, top, right, bottom))
      }
    }

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      if (paint.style == Paint.Style.FILL) colors.add(paint.color)
    }
  }

  @Test
  fun onlyTheLinesTheCanvasShowsDraw() {
    val text = withCode("`a`\n\n\n\n\n\n\n\n\n\n`b`", 0, 3)
    text.setSpan(CodeBackgroundSpan(styleConfig()), text.length - 3, text.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val layout = layout(text)
    val recorder = Recorder()
    recorder.clipRect(0f, 0f, 2000f, layout.getLineBottom(0).toFloat())
    TextBackgroundDrawer().draw(recorder, layout, text, 0f, 0f)
    assertEquals(1, recorder.fills.size)
  }

  @Test
  fun aHighlightBandSitsUnderItsGlyphs() {
    val mark = MarkdownASTNode(NodeType.Highlight, children = listOf(text("marked")))
    val text = render(styleConfig(highlight = mapOf("backgroundColor" to Color.YELLOW)), paragraph(text("Some "), mark, text(" words")))
    val layout = layout(text)
    val recorder = OrderRecorder()
    TextBackgroundDrawer().draw(recorder, layout, text, 0f, 0f)
    assertCovers(layout, 5, 11, recorder.rects.single())
  }

  @Test
  fun aConcealedSpoilerHidesTheCodeInsideIt() {
    val code = MarkdownASTNode(NodeType.Code, children = listOf(text("fetch()")))
    val text = render(styleConfig(), paragraph(text("See "), MarkdownASTNode(NodeType.Spoiler, children = listOf(code))))
    val layout = layout(text)
    assertTrue(draw(layout).isEmpty())

    text.getSpans(0, text.length, SpoilerSpan::class.java).forEach { it.markRevealed() }
    assertEquals(1, draw(layout).size)
  }

  // An inline element that changes width in place, as an image that failed or a pill that lost its icon.
  private class Box(
    var width: Int,
  ) : ReplacementSpan() {
    override fun getSize(
      paint: Paint,
      text: CharSequence?,
      start: Int,
      end: Int,
      fm: Paint.FontMetricsInt?,
    ) = width

    override fun draw(
      canvas: Canvas,
      text: CharSequence?,
      start: Int,
      end: Int,
      x: Float,
      top: Int,
      y: Int,
      bottom: Int,
      paint: Paint,
    ) = Unit
  }

  @Test
  fun aDrawerKeepsPositionsUntilTheTextOrAnInlineElementChanges() {
    val box = Box(40)
    val text = withCode("ab x fetch() wait", 5, 12)
    text.setSpan(box, 3, 4, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val layout = DynamicLayout.Builder.obtain(text, paint, 1600).build()
    val drawer = TextBackgroundDrawer()
    assertCovers(layout, 5, 12, draw(layout, drawer).single())

    // The element before the code widens in place: the layout reflows the line, whose text is the same.
    box.width = 200
    text.setSpan(box, 3, 4, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    TextBackgroundDrawer.noteReflow()
    assertCovers(layout, 5, 12, draw(layout, drawer).single())

    // The text before the code changes width but not length: positions on its line are found again.
    text.replace(0, 2, "WW")
    drawer.invalidateFrom(0)
    assertCovers(layout, 5, 12, draw(layout, drawer).single())
  }
}
