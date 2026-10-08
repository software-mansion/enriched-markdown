package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spannable
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.CodeBackgroundSpan
import com.swmansion.enriched.markdown.spans.HighlightSpan
import com.swmansion.enriched.markdown.spans.registerWithSpans
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.highlight
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.ParameterizedRobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Covers where inline code and highlight backgrounds are painted: over the run's glyphs. */
@RunWith(ParameterizedRobolectricTestRunner::class)
@Config(sdk = [28])
// Robolectric's legacy graphics report zero text widths; the native runtime measures for real.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class InlineBackgroundPaintingTest(
  private val kind: Kind,
) {
  private val context: Context = ApplicationProvider.getApplicationContext()

  /** Runs that paint a background, in [BACKGROUND] with text in [RUN_INK] so both can be found. */
  enum class Kind(
    val spanClass: Class<*>,
  ) {
    CODE(CodeBackgroundSpan::class.java) {
      override fun node(content: String) = code(content)

      override fun style(textAlign: TextAlignment?) =
        MarkdownRenderTestSupport.styleWithCode(
          MarkdownRenderTestSupport.defaultStyle.codeStyle.copy(color = RUN_INK, backgroundColor = BACKGROUND),
          textAlign,
        )
    },
    HIGHLIGHT(HighlightSpan::class.java) {
      override fun node(content: String) = highlight(text(content))

      override fun style(textAlign: TextAlignment?) =
        MarkdownRenderTestSupport.styleWithHighlight(
          MarkdownRenderTestSupport.defaultStyle.highlightStyle.copy(color = RUN_INK, backgroundColor = BACKGROUND),
          textAlign,
        )
    }, ;

    abstract fun node(content: String): MarkdownASTNode

    abstract fun style(textAlign: TextAlignment?): StyleConfig
  }

  companion object {
    private const val WIDTH = 400
    private const val BACKGROUND = 0xFF224488.toInt()
    private const val RUN_INK = 0xFFFF0000.toInt()

    // Pixels an anti-aliased glyph edge may stray past the background.
    private const val INK_TOLERANCE = 1.5f

    @JvmStatic
    @ParameterizedRobolectricTestRunner.Parameters(name = "{0}")
    fun kinds() = Kind.entries.map { arrayOf(it) }
  }

  /** Records [BACKGROUND] fills without painting them, so its bitmap holds only glyphs. */
  private class RecordingCanvas(
    bitmap: Bitmap,
  ) : Canvas(bitmap) {
    val backgrounds = mutableListOf<RectF>()

    override fun drawPath(
      path: Path,
      paint: Paint,
    ) {
      if (paint.style == Paint.Style.FILL && paint.color == BACKGROUND) {
        backgrounds.add(RectF().also { path.computeBounds(it, true) })
      }
    }

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      if (paint.style == Paint.Style.FILL && paint.color == BACKGROUND) backgrounds.add(RectF(left, top, right, bottom))
    }
  }

  private fun style(textAlign: TextAlignment? = null): StyleConfig = kind.style(textAlign)

  /** The run under test, holding [content]. */
  private fun styledRun(content: String): MarkdownASTNode = kind.node(content)

  private class Drawn(
    val textView: TextView,
    val rendered: Spannable,
    val backgrounds: List<RectF>,
    val glyphs: Bitmap,
    spanClass: Class<*>,
  ) {
    private val span = rendered.getSpans(0, rendered.length, spanClass).single()
    val runStart: Int get() = rendered.getSpanStart(span)
    val runEnd: Int get() = rendered.getSpanEnd(span)
  }

  /** Draws [document] in a view that registers with its spans, or a plain TextView if not [registered]. */
  private fun draw(
    document: MarkdownASTNode,
    style: StyleConfig = style(),
    registered: Boolean = true,
  ): Drawn {
    val rendered = render(document, style)
    val textView = if (registered) EnrichedMarkdownInternalText(context) else TextView(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    if (registered) textView.registerWithSpans(rendered)
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, WIDTH, textView.measuredHeight)

    val glyphs = Bitmap.createBitmap(WIDTH, maxOf(textView.height, 1), Bitmap.Config.ARGB_8888)
    val canvas = RecordingCanvas(glyphs)
    requireNotNull(textView.layout).draw(canvas)
    return Drawn(textView, rendered, canvas.backgrounds, glyphs, kind.spanClass)
  }

  /** Asserts the background spans [from]..[to], in either direction. */
  private fun assertCoversTheRun(
    drawn: Drawn,
    from: Int = drawn.runStart,
    to: Int = drawn.runEnd,
  ) {
    assertCovers(requireNotNull(drawn.textView.layout), drawn.backgrounds.single(), from, to)
  }

  private fun assertCovers(
    layout: Layout,
    background: RectF,
    from: Int,
    to: Int,
  ) {
    val fromX = layout.getPrimaryHorizontal(from)
    val toX = layout.getPrimaryHorizontal(to)
    assertTrue("The run must have a width for this to be meaningful", fromX != toX)
    assertEquals(minOf(fromX, toX), background.left, 0.01f)
    assertEquals(maxOf(fromX, toX), background.right, 0.01f)
  }

  /** Asserts one background per line, each spanning only the run's glyphs on it. */
  private fun assertCoversEachLineOfTheRun(drawn: Drawn) {
    val layout = requireNotNull(drawn.textView.layout)
    val firstLine = layout.getLineForOffset(drawn.runStart)
    val lastLine = layout.getLineForOffset(drawn.runEnd - 1)
    assertTrue("The run must wrap for this to be meaningful", lastLine - firstLine >= 2)
    assertEquals(lastLine - firstLine + 1, drawn.backgrounds.size)

    for (line in firstLine..lastLine) {
      val continues = drawn.runEnd > layout.getLineEnd(line)
      val to = if (continues) layout.getLineEnd(line) - 1 else drawn.runEnd
      if (continues) assertEquals("Line $line must wrap on a space", ' ', drawn.rendered[to])
      assertCovers(layout, drawn.backgrounds[line - firstLine], maxOf(drawn.runStart, layout.getLineStart(line)), to)
    }
  }

  /**
   * Asserts the backgrounds cover all of the run's glyphs and none of the rest, read from pixels.
   * Caret positions, which [assertCovers] uses, are wrong where the direction changes.
   */
  private fun assertCoversOnlyTheRunsGlyphs(drawn: Drawn) {
    val layout = requireNotNull(drawn.textView.layout)
    val backgroundsByLine = drawn.backgrounds.groupBy { layout.getLineForVertical(it.centerY().toInt()) }
    var runPixels = 0
    var otherPixels = 0
    for (y in 0 until drawn.glyphs.height) {
      val line = layout.getLineForVertical(y)
      val backgrounds = backgroundsByLine[line].orEmpty()
      for (x in 0 until drawn.glyphs.width) {
        val pixel = drawn.glyphs.getPixel(x, y)
        // Faint edge pixels are too pale to classify.
        if (Color.alpha(pixel) < 128) continue
        val centerX = x + 0.5f
        if (Color.red(pixel) > 192 && Color.green(pixel) < 64 && Color.blue(pixel) < 64) {
          runPixels++
          assertTrue(
            "The run's glyph at ($x, $y) must lie on a background, not outside $backgrounds",
            backgrounds.any { centerX >= it.left - INK_TOLERANCE && centerX <= it.right + INK_TOLERANCE },
          )
        } else {
          otherPixels++
          assertTrue(
            "The glyph at ($x, $y) is not the run's, so it must not lie on any of $backgrounds",
            backgrounds.none { centerX > it.left + INK_TOLERANCE && centerX < it.right - INK_TOLERANCE },
          )
        }
      }
    }
    assertTrue("The run and the text around it must both be drawn for this to be meaningful", runPixels > 0 && otherPixels > 0)
  }

  /** Draws a run wrapping across 3+ lines, between [before] and [after]. */
  private fun drawWrappedRun(
    before: String,
    word: String,
    after: String,
    style: StyleConfig = style(),
  ): Drawn = draw(document(paragraph(text(before), styledRun("$word ".repeat(40).trimEnd()), text(after))), style)

  /** Draws a run of [content] that ends the first line, followed by [longWord]. */
  private fun drawRunEndingAWrappedLine(
    content: String,
    longWord: String,
  ): Drawn {
    val drawn = draw(document(paragraph(styledRun(content), text(longWord))))
    val layout = requireNotNull(drawn.textView.layout)
    assertTrue("The text must wrap for this to be meaningful", layout.lineCount > 1)
    assertEquals("The first line must end where the run does", drawn.runEnd, layout.getLineEnd(0))
    return drawn
  }

  @Test
  fun theBackgroundCoversTheRun() {
    assertCoversTheRun(draw(document(paragraph(text("call "), styledRun("render()"), text(" once")))))
  }

  @Test
  fun theBackgroundFollowsCenteredText() {
    val drawn = draw(document(paragraph(text("call "), styledRun("render()"), text(" once"))), style(TextAlignment.CENTER))

    assertTrue("The line must be centered for this to be meaningful", drawn.backgrounds.single().left > WIDTH / 4f)
    assertCoversTheRun(drawn)
  }

  @Test
  fun theBackgroundFollowsRightAlignedText() {
    val drawn = draw(document(paragraph(text("call "), styledRun("render()"), text(" once"))), style(TextAlignment.RIGHT))

    assertTrue("The line must be right-aligned for this to be meaningful", drawn.backgrounds.single().left > WIDTH / 2f)
    assertCoversTheRun(drawn)
  }

  @Test
  fun theBackgroundCoversRightToLeftRun() {
    val drawn = draw(document(paragraph(text("קרא ל"), styledRun("שלום"), text(" פעם אחת"))))

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertTrue("The line must start on the right for this to be meaningful", drawn.backgrounds.single().left > WIDTH / 2f)
    assertCoversTheRun(drawn)
  }

  @Test
  fun runEndingAWrappedLineStopsAtItsLastGlyph() {
    val drawn = drawRunEndingAWrappedLine("render() ", "a".repeat(200))

    // The trailing space isn't drawn, so isn't covered.
    assertCoversTheRun(drawn, to = drawn.runEnd - 1)
  }

  @Test
  fun rightToLeftRunEndingAWrappedLineStopsAtItsLastGlyph() {
    val drawn = drawRunEndingAWrappedLine("שלום ", "א".repeat(200))

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertCoversTheRun(drawn, to = drawn.runEnd - 1)
  }

  @Test
  fun wrappedRunEndsAtItsLastGlyphOnEachLine() {
    assertCoversEachLineOfTheRun(drawWrappedRun("call ", "render", " once"))
  }

  @Test
  fun wrappedRunFollowsCenteredText() {
    assertCoversEachLineOfTheRun(drawWrappedRun("call ", "render", " once", style(TextAlignment.CENTER)))
  }

  @Test
  fun wrappedRunFollowsRightAlignedText() {
    assertCoversEachLineOfTheRun(drawWrappedRun("call ", "render", " once", style(TextAlignment.RIGHT)))
  }

  @Test
  fun wrappedRightToLeftRunCoversEachLine() {
    val drawn = drawWrappedRun("קרא ל", "שלום", " פעם אחת")

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertCoversEachLineOfTheRun(drawn)
  }

  @Test
  fun wrappedLeftToRightRunInRightToLeftTextCoversEachLine() {
    val drawn = drawWrappedRun("קרא ל", "render", " פעם אחת")

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertCoversEachLineOfTheRun(drawn)
  }

  @Test
  fun leftToRightRunInRightToLeftTextCoversOnlyItsOwnWords() {
    // The caret where Hebrew turns to English is past " world".
    val drawn = draw(document(paragraph(text("שלום "), styledRun("hello"), text(" world"))))

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertEquals(1, drawn.backgrounds.size)
    assertCoversOnlyTheRunsGlyphs(drawn)
  }

  @Test
  fun rightToLeftRunInLeftToRightTextCoversOnlyItsOwnWords() {
    val drawn = draw(document(paragraph(text("call "), styledRun("שלום"), text(" עולם once"))))

    assertEquals(Layout.DIR_LEFT_TO_RIGHT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertEquals(1, drawn.backgrounds.size)
    assertCoversOnlyTheRunsGlyphs(drawn)
  }

  @Test
  fun runDrawnInPiecesGetsABackgroundPerPiece() {
    // Drawn right to left, " עולם" lands between the run's two words.
    val drawn = draw(document(paragraph(text("call "), styledRun("render שלום"), text(" עולם once"))))

    assertEquals(Layout.DIR_LEFT_TO_RIGHT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertEquals(2, drawn.backgrounds.size)
    assertCoversOnlyTheRunsGlyphs(drawn)
  }

  @Test
  fun runBrokenMidWordStaysWithinEachLinesGlyphs() {
    val drawn = draw(document(paragraph(text("call "), styledRun("a".repeat(120)), text(" once"))))
    val layout = requireNotNull(drawn.textView.layout)

    assertTrue("The run must break mid-word for this to be meaningful", layout.getLineEnd(0) < drawn.runEnd)
    assertCoversOnlyTheRunsGlyphs(drawn)
    for (background in drawn.backgrounds) {
      val line = layout.getLineForVertical(background.centerY().toInt())
      assertTrue("$background must end at line $line's glyphs", background.right <= layout.getLineRight(line) + 0.5f)
    }
  }

  @Test
  fun theBackgroundFollowsTheListIndent() {
    val drawn = draw(document(unorderedList(listItem(paragraph(styledRun("render()"))))))

    assertTrue("The run must be indented for this to be meaningful", drawn.backgrounds.single().left > 0f)
    assertCoversTheRun(drawn)
  }

  @Test
  fun aViewThatDidNotRegisterStillPlacesAStartAlignedRun() {
    assertCoversTheRun(
      draw(document(paragraph(text("call "), styledRun("render()"), text(" once"))), registered = false),
    )
  }

  @Test
  fun aViewThatDidNotRegisterStillFollowsTheListIndent() {
    assertCoversTheRun(
      draw(document(unorderedList(listItem(paragraph(text("call "), styledRun("render()"))))), registered = false),
    )
  }

  @Test
  fun aViewThatDidNotRegisterStillEndsAnIndentedRunThatStartsTheLine() {
    assertCoversTheRun(
      draw(document(unorderedList(listItem(paragraph(styledRun("render()"), text(" once"))))), registered = false),
    )
  }
}
