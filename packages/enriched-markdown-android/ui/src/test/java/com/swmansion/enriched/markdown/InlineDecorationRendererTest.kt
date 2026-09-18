package com.swmansion.enriched.markdown

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.text.SpannableString
import android.text.TextPaint
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.HighlightSpan
import com.swmansion.enriched.markdown.spans.StrikethroughSpan
import com.swmansion.enriched.markdown.spans.StrongSpan
import com.swmansion.enriched.markdown.spans.UnderlineSpan
import com.swmansion.enriched.markdown.styles.HighlightStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertContains
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertSpanCovers
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleWithDecorationColors
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleWithHighlight
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.highlight
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.strikethrough
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.underline
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class InlineDecorationRendererTest {
  private val red = 0xFFFF0000.toInt()
  private val blue = 0xFF0000FF.toInt()
  private val inheritedColor = 0xFF123456.toInt()

  private companion object {
    const val BASELINE = 100
    const val LINE_PADDING = 20
  }

  // MARK: Strikethrough

  @Test
  fun strikethroughSpanCoversOnlyStruckText() {
    val rendered =
      render(
        document(
          paragraph(
            strikethrough(text("strike")),
            text(" plain"),
          ),
        ),
      )

    rendered.assertContains("strike plain")
    rendered.assertSpanCovers("strike", StrikethroughSpan::class.java)
    assertEquals(0, rendered.spansOver("plain", StrikethroughSpan::class.java).size)
  }

  @Test
  fun strikethroughDrawsStrikeThruLine() {
    val rendered = render(document(paragraph(strikethrough(text("strike")))))

    val paint = rendered.paintAfterSpan("strike", StrikethroughSpan::class.java)

    assertTrue(paint.isStrikeThruText)
  }

  @Test
  fun strikethroughInheritsColorWhenUnset() {
    val rendered = render(document(paragraph(strikethrough(text("strike")))))

    val paint = rendered.paintAfterSpan("strike", StrikethroughSpan::class.java)

    assertEquals(inheritedColor, paint.color)
  }

  @Test
  fun strikethroughAppliesConfiguredColor() {
    val rendered =
      render(
        document(paragraph(strikethrough(text("strike")))),
        styleWithDecorationColors(strikethroughColor = red),
      )

    val paint = rendered.paintAfterSpan("strike", StrikethroughSpan::class.java)

    assertEquals(red, paint.color)
  }

  @Test
  fun strikethroughKeepsNestedStrongSpan() {
    val rendered = render(document(paragraph(strikethrough(strong(text("both"))))))

    rendered.assertSpanCovers("both", StrikethroughSpan::class.java)
    rendered.assertSpanCovers("both", StrongSpan::class.java)
  }

  // MARK: Underline

  @Test
  fun underlineSpanCoversOnlyUnderlinedText() {
    val rendered =
      render(
        document(
          paragraph(
            underline(text("under")),
            text(" plain"),
          ),
        ),
      )

    rendered.assertContains("under plain")
    rendered.assertSpanCovers("under", UnderlineSpan::class.java)
    assertEquals(0, rendered.spansOver("plain", UnderlineSpan::class.java).size)
  }

  @Test
  fun underlineDrawsUnderline() {
    val rendered = render(document(paragraph(underline(text("under")))))

    val paint = rendered.paintAfterSpan("under", UnderlineSpan::class.java)

    assertTrue(paint.isUnderlineText)
  }

  @Test
  fun underlineInheritsColorWhenUnset() {
    val rendered = render(document(paragraph(underline(text("under")))))

    val paint = rendered.paintAfterSpan("under", UnderlineSpan::class.java)

    assertEquals(inheritedColor, paint.color)
  }

  @Test
  fun underlineAppliesConfiguredColor() {
    val rendered =
      render(
        document(paragraph(underline(text("under")))),
        styleWithDecorationColors(underlineColor = blue),
      )

    val paint = rendered.paintAfterSpan("under", UnderlineSpan::class.java)

    assertEquals(blue, paint.color)
  }

  @Test
  fun underlineKeepsNestedStrongSpan() {
    val rendered = render(document(paragraph(underline(strong(text("both"))))))

    rendered.assertSpanCovers("both", UnderlineSpan::class.java)
    rendered.assertSpanCovers("both", StrongSpan::class.java)
  }

  // MARK: Highlight

  @Test
  fun highlightSpanCoversOnlyHighlightedText() {
    val rendered =
      render(
        document(
          paragraph(
            highlight(text("marked")),
            text(" plain"),
          ),
        ),
      )

    rendered.assertContains("marked plain")
    rendered.assertSpanCovers("marked", HighlightSpan::class.java)
    assertEquals(0, rendered.spansOver("plain", HighlightSpan::class.java).size)
  }

  @Test
  fun highlightPaintsDefaultBackground() {
    val rendered = render(document(paragraph(highlight(text("marked")))))

    val canvas = rendered.drawHighlightBackground()

    assertEquals(0xFFFEF08A.toInt(), canvas.color)
  }

  /**
   * Regression test: the background used to come from [TextPaint.bgColor], which fills the whole
   * line box. `LineHeightSpan` pads that box to reach the configured line height, so the highlight
   * floated well above the text it marked.
   */
  @Test
  fun highlightBackgroundHugsTextRatherThanLineBox() {
    val rendered = render(document(paragraph(highlight(text("marked")))))

    val paint = TextPaint().apply { textSize = 16f }
    val metrics = paint.fontMetricsInt
    assertTrue("Test needs real font metrics to be meaningful", metrics.ascent < 0 && metrics.descent > 0)
    val lineTop = BASELINE + metrics.ascent - LINE_PADDING
    val lineBottom = BASELINE + metrics.descent + LINE_PADDING

    val canvas = rendered.drawHighlightBackground(paint, lineTop, lineBottom)
    val band = canvas.rect!!

    assertEquals((BASELINE + metrics.ascent).toFloat(), band.top, 0.5f)
    assertEquals((BASELINE + metrics.descent).toFloat(), band.bottom, 0.5f)
    assertTrue("Band must not reach the padded line top", band.top > lineTop)
    assertTrue("Band must not reach the padded line bottom", band.bottom < lineBottom)
  }

  @Test
  fun highlightInheritsColorWhenUnset() {
    val rendered = render(document(paragraph(highlight(text("marked")))))

    val paint = rendered.paintAfterSpan("marked", HighlightSpan::class.java)

    assertEquals(inheritedColor, paint.color)
  }

  @Test
  fun highlightAppliesConfiguredColors() {
    val rendered =
      render(
        document(paragraph(highlight(text("marked")))),
        styleWithHighlight(HighlightStyle(color = red, backgroundColor = blue)),
      )

    val paint = rendered.paintAfterSpan("marked", HighlightSpan::class.java)

    assertEquals(red, paint.color)
    assertEquals(blue, rendered.drawHighlightBackground().color)
  }

  @Test
  fun highlightDrawsNothingWhenBackgroundIsTransparent() {
    val rendered =
      render(
        document(paragraph(highlight(text("marked")))),
        styleWithHighlight(HighlightStyle(color = null, backgroundColor = 0)),
      )

    assertEquals(null, rendered.drawHighlightBackground().rect)
  }

  @Test
  fun highlightKeepsNestedStrongSpan() {
    val rendered = render(document(paragraph(highlight(strong(text("both"))))))

    rendered.assertSpanCovers("both", HighlightSpan::class.java)
    rendered.assertSpanCovers("both", StrongSpan::class.java)
  }

  /** Records the one rect a [LineBackgroundSpan] paints, so its bounds can be asserted. */
  private class RecordingCanvas : Canvas() {
    var rect: RectF? = null
    var color: Int = 0

    override fun drawRect(
      left: Float,
      top: Float,
      right: Float,
      bottom: Float,
      paint: Paint,
    ) {
      rect = RectF(left, top, right, bottom)
      color = paint.color
    }
  }

  /** Runs the highlight's background pass over a line box padded above and below. */
  private fun SpannableString.drawHighlightBackground(
    paint: TextPaint = TextPaint().apply { textSize = 16f },
    lineTop: Int = BASELINE - LINE_PADDING,
    lineBottom: Int = BASELINE + LINE_PADDING,
  ): RecordingCanvas {
    val span = spansOver("marked", HighlightSpan::class.java).first()
    return RecordingCanvas().also {
      span.drawBackground(it, paint, 0, 500, lineTop, BASELINE, lineBottom, this, 0, length, 0)
    }
  }

  private fun <T> SpannableString.spansOver(
    text: String,
    spanClass: Class<T>,
  ): Array<out T> {
    val start = toString().indexOf(text)
    assertTrue("Expected rendered text to contain \"$text\"", start >= 0)
    return getSpans(start, start + text.length, spanClass)
  }

  /** Runs the span's draw state over a paint seeded with an inherited color. */
  private fun <T : android.text.style.CharacterStyle> SpannableString.paintAfterSpan(
    text: String,
    spanClass: Class<T>,
  ): TextPaint {
    val span = spansOver(text, spanClass).firstOrNull()
    assertTrue("Expected a ${spanClass.simpleName} over \"$text\"", span != null)
    return TextPaint().apply {
      color = inheritedColor
      span!!.updateDrawState(this)
    }
  }
}
