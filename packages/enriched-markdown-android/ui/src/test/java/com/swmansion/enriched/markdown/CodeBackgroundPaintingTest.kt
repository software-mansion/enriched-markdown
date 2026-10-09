package com.swmansion.enriched.markdown

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spannable
import android.util.TypedValue
import android.view.View
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.CodeBackgroundSpan
import com.swmansion.enriched.markdown.spans.registerCodeBackgrounds
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.code
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/**
 * Covers where an inline code background is painted: over the code's glyphs, as the layout that
 * draws the text places them.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
// Robolectric's legacy graphics report zero text widths; the native runtime measures for real.
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class CodeBackgroundPaintingTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private companion object {
    const val WIDTH = 400
    const val BACKGROUND = 0xFF224488.toInt()
  }

  /** A [Canvas] that remembers the bounds of every path filled in [BACKGROUND]. */
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
      super.drawPath(path, paint)
    }
  }

  private fun style(textAlign: TextAlignment? = null): StyleConfig =
    MarkdownRenderTestSupport.styleWithCode(
      MarkdownRenderTestSupport.defaultStyle.codeStyle.copy(backgroundColor = BACKGROUND),
      textAlign,
    )

  private class Drawn(
    val textView: TextView,
    val rendered: Spannable,
    val backgrounds: List<RectF>,
  ) {
    private val span = rendered.getSpans(0, rendered.length, CodeBackgroundSpan::class.java).single()
    val codeStart: Int get() = rendered.getSpanStart(span)
    val codeEnd: Int get() = rendered.getSpanEnd(span)
  }

  /**
   * Draws [document] in a markdown text view that registers with its code backgrounds, as
   * SegmentViewCreators does, or, when not [registered], in a plain TextView that does not.
   */
  private fun draw(
    document: MarkdownASTNode,
    style: StyleConfig = style(),
    registered: Boolean = true,
  ): Drawn {
    val rendered = render(document, style)
    val textView = if (registered) EnrichedMarkdownInternalText(context) else TextView(context)
    textView.setTextSize(TypedValue.COMPLEX_UNIT_PX, style.paragraphStyle.fontSize)
    textView.text = rendered
    if (registered) textView.registerCodeBackgrounds(rendered)
    textView.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    textView.layout(0, 0, WIDTH, textView.measuredHeight)

    val canvas = RecordingCanvas(Bitmap.createBitmap(WIDTH, maxOf(textView.height, 1), Bitmap.Config.ARGB_8888))
    requireNotNull(textView.layout).draw(canvas)
    return Drawn(textView, rendered, canvas.backgrounds)
  }

  /**
   * Asserts the background spans the glyphs from [from] to [to]. Their x positions are compared by
   * their min and max, since in right-to-left text [from] lies to the right of [to].
   */
  private fun assertCoversTheCode(
    drawn: Drawn,
    from: Int = drawn.codeStart,
    to: Int = drawn.codeEnd,
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
    assertTrue("The code must have a width for this to be meaningful", fromX != toX)
    assertEquals(minOf(fromX, toX), background.left, 0.01f)
    assertEquals(maxOf(fromX, toX), background.right, 0.01f)
  }

  /**
   * Asserts that code wrapping across lines gets one background per line, each spanning only the
   * code's glyphs on that line. A line the code continues past ends at the space it wraps on,
   * which is not drawn, so neither is its background.
   */
  private fun assertCoversEachLineOfTheCode(drawn: Drawn) {
    val layout = requireNotNull(drawn.textView.layout)
    val firstLine = layout.getLineForOffset(drawn.codeStart)
    val lastLine = layout.getLineForOffset(drawn.codeEnd - 1)
    assertTrue("The code must wrap for this to be meaningful", lastLine - firstLine >= 2)
    assertEquals(lastLine - firstLine + 1, drawn.backgrounds.size)

    for (line in firstLine..lastLine) {
      val continues = drawn.codeEnd > layout.getLineEnd(line)
      val to = if (continues) layout.getLineEnd(line) - 1 else drawn.codeEnd
      if (continues) assertEquals("Line $line must wrap on a space", ' ', drawn.rendered[to])
      assertCovers(layout, drawn.backgrounds[line - firstLine], maxOf(drawn.codeStart, layout.getLineStart(line)), to)
    }
  }

  /** Draws code long enough to wrap across at least three lines, between [before] and [after]. */
  private fun drawWrappedCode(
    before: String,
    word: String,
    after: String,
    style: StyleConfig = style(),
  ): Drawn = draw(document(paragraph(text(before), code("$word ".repeat(40).trimEnd()), text(after))), style)

  /**
   * Draws [code] followed by a word too long to share its line, so the first line wraps right
   * after the code's trailing space and the code's end offset is also the next line's start.
   */
  private fun drawCodeEndingAWrappedLine(
    code: String,
    longWord: String,
  ): Drawn {
    val drawn = draw(document(paragraph(code(code), text(longWord))))
    val layout = requireNotNull(drawn.textView.layout)
    assertTrue("The text must wrap for this to be meaningful", layout.lineCount > 1)
    assertEquals("The first line must end where the code does", drawn.codeEnd, layout.getLineEnd(0))
    return drawn
  }

  @Test
  fun theBackgroundCoversTheCode() {
    assertCoversTheCode(draw(document(paragraph(text("call "), code("render()"), text(" once")))))
  }

  @Test
  fun theBackgroundFollowsCenteredText() {
    val drawn = draw(document(paragraph(text("call "), code("render()"), text(" once"))), style(TextAlignment.CENTER))

    assertTrue("The line must be centered for this to be meaningful", drawn.backgrounds.single().left > WIDTH / 4f)
    assertCoversTheCode(drawn)
  }

  @Test
  fun theBackgroundFollowsRightAlignedText() {
    val drawn = draw(document(paragraph(text("call "), code("render()"), text(" once"))), style(TextAlignment.RIGHT))

    assertTrue("The line must be right-aligned for this to be meaningful", drawn.backgrounds.single().left > WIDTH / 2f)
    assertCoversTheCode(drawn)
  }

  @Test
  fun theBackgroundCoversRightToLeftCode() {
    val drawn = draw(document(paragraph(text("קרא ל"), code("שלום"), text(" פעם אחת"))))

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertTrue("The line must start on the right for this to be meaningful", drawn.backgrounds.single().left > WIDTH / 2f)
    assertCoversTheCode(drawn)
  }

  @Test
  fun codeEndingAWrappedLineStopsAtItsLastGlyph() {
    val drawn = drawCodeEndingAWrappedLine("render() ", "a".repeat(200))

    // The trailing space where the line wraps is not drawn, so neither is its background.
    assertCoversTheCode(drawn, to = drawn.codeEnd - 1)
  }

  @Test
  fun rightToLeftCodeEndingAWrappedLineStopsAtItsLastGlyph() {
    val drawn = drawCodeEndingAWrappedLine("שלום ", "א".repeat(200))

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertCoversTheCode(drawn, to = drawn.codeEnd - 1)
  }

  @Test
  fun wrappedCodeEndsAtItsLastGlyphOnEachLine() {
    assertCoversEachLineOfTheCode(drawWrappedCode("call ", "render", " once"))
  }

  @Test
  fun wrappedCodeFollowsCenteredText() {
    assertCoversEachLineOfTheCode(drawWrappedCode("call ", "render", " once", style(TextAlignment.CENTER)))
  }

  @Test
  fun wrappedCodeFollowsRightAlignedText() {
    assertCoversEachLineOfTheCode(drawWrappedCode("call ", "render", " once", style(TextAlignment.RIGHT)))
  }

  @Test
  fun wrappedRightToLeftCodeCoversEachLine() {
    val drawn = drawWrappedCode("קרא ל", "שלום", " פעם אחת")

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertCoversEachLineOfTheCode(drawn)
  }

  @Test
  fun wrappedLeftToRightCodeInRightToLeftTextCoversEachLine() {
    val drawn = drawWrappedCode("קרא ל", "render", " פעם אחת")

    assertEquals(Layout.DIR_RIGHT_TO_LEFT, requireNotNull(drawn.textView.layout).getParagraphDirection(0))
    assertCoversEachLineOfTheCode(drawn)
  }

  @Test
  fun theBackgroundFollowsTheListIndent() {
    val drawn = draw(document(unorderedList(listItem(paragraph(code("render()"))))))

    assertTrue("The code must be indented for this to be meaningful", drawn.backgrounds.single().left > 0f)
    assertCoversTheCode(drawn)
  }

  @Test
  fun aViewThatDidNotRegisterStillPlacesStartAlignedCode() {
    assertCoversTheCode(
      draw(document(paragraph(text("call "), code("render()"), text(" once"))), registered = false),
    )
  }

  @Test
  fun aViewThatDidNotRegisterStillFollowsTheListIndent() {
    assertCoversTheCode(
      draw(document(unorderedList(listItem(paragraph(text("call "), code("render()"))))), registered = false),
    )
  }

  @Test
  fun aViewThatDidNotRegisterStillEndsIndentedCodeThatStartsTheLine() {
    assertCoversTheCode(
      draw(document(unorderedList(listItem(paragraph(code("render()"), text(" once"))))), registered = false),
    )
  }
}
