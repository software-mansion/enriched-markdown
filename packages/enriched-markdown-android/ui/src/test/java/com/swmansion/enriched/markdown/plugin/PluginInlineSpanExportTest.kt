package com.swmansion.enriched.markdown.plugin

import android.text.Spannable
import android.text.SpannableString
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.FakeInlineSpan
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTML
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithFullSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.heading
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
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
  fun aSpanInsideAHeadingStaysInPlaceOnTheHeadingLine() {
    val extracted = extractWithSpan(document(heading(2, text("Energy "), text(PLACEHOLDER), text(" law"))), "E")

    assertEquals("## Energy @@E@@ law\n", extracted)
  }

  @Test
  fun aSpanOpeningAListItemKeepsTheListMarker() {
    val extracted = extractWithSpan(document(unorderedList(listItem(paragraph(text(PLACEHOLDER), text(" is small"))))), "E")

    assertEquals("- @@E@@ is small", extracted)
  }

  @Test
  fun aSpanOpeningABlockquoteLineKeepsTheQuoteMarker() {
    val extracted = extractWithSpan(document(blockquote(paragraph(text(PLACEHOLDER), text(" quoted")))), "E")

    assertEquals("> @@E@@ quoted", extracted)
  }

  @Test
  fun aSpanInsideInlineFormattingIsWrappedByIt() {
    val extracted = extractWithSpan(document(paragraph(strong(text(PLACEHOLDER)))), "x")

    assertEquals("**@@x@@**", extracted)
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
    assertFalse(generateHTML(spannableWith(FakeInlineSpan("x", htmlText = null))).contains("<code"))
  }

  @Test
  fun plainTextCopyAsksEachSpanForItsText() {
    val text =
      SpannableString("a ￼ b ￼ c").apply {
        setSpan(FakeInlineSpan("x^2"), 2, 3, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        setSpan(FakeInlineSpan("y"), 6, 7, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
      }

    assertEquals("a plain:x^2 b plain:y c", text.readableText())
  }

  /** Renders [document] and lays a [FakeInlineSpan] over its one [PLACEHOLDER], as a plugin's renderer would. */
  private fun extractWithSpan(
    document: MarkdownASTNode,
    source: String,
  ): String {
    val spannable: Spannable = render(document)
    val index = spannable.indexOf(PLACEHOLDER)
    spannable.setSpan(FakeInlineSpan(source), index, index + 1, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    return MarkdownExtractor.extractFromSpannable(spannable, 0, spannable.length)
  }

  private fun spannableWith(span: FakeInlineSpan): SpannableString =
    SpannableString("￼").apply { setSpan(span, 0, 1, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE) }

  private companion object {
    const val PLACEHOLDER = "\uFFFC"
  }
}
