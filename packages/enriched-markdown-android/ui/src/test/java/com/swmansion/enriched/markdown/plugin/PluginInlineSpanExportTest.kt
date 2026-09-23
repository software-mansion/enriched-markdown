package com.swmansion.enriched.markdown.plugin

import android.text.SpannableString
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.FakeInlineSpan
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTML
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithFullSelection
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Core round-trips a plugin's replacement span through both exports without knowing what it is:
 * the span, not core, owns the delimiters.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginInlineSpanExportTest {
  @Test
  fun markdownExtractionAsksTheSpanForItsSource() {
    val extracted = MarkdownExtractor.getMarkdownForSelection(createTextViewWithFullSelection(spannableWith(FakeInlineSpan("x^2"))))

    assertEquals("@@x^2@@", extracted)
  }

  @Test
  fun htmlExportWrapsTheSpanTextInInlineCodeStyling() {
    val html = generateHTML(spannableWith(FakeInlineSpan("x^2")))

    assertTrue(html, html.contains("<code style=\"background-color: "))
    assertTrue(html, html.contains("x^2</code>"))
  }

  @Test
  fun htmlExportEscapesTheSpanTextAndOmitsItWhenNull() {
    assertTrue(generateHTML(spannableWith(FakeInlineSpan("a<b"))).contains("a&lt;b</code>"))
    assertTrue(!generateHTML(spannableWith(FakeInlineSpan("x", htmlText = null))).contains("<code"))
  }

  private fun spannableWith(span: FakeInlineSpan): SpannableString =
    SpannableString("￼").apply { setSpan(span, 0, 1, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE) }
}
