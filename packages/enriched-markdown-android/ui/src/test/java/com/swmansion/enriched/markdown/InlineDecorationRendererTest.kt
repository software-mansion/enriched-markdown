package com.swmansion.enriched.markdown

import android.text.SpannableString
import android.text.TextPaint
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.StrikethroughSpan
import com.swmansion.enriched.markdown.spans.StrongSpan
import com.swmansion.enriched.markdown.spans.UnderlineSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertContains
import com.swmansion.enriched.markdown.test.MarkdownRenderAssertions.assertSpanCovers
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleWithDecorationColors
import com.swmansion.enriched.markdown.test.TestAstFactory.document
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
