package com.swmansion.enriched.markdown.accessibility

import android.text.Spannable
import android.text.SpannableString
import android.view.View.MeasureSpec
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.test.FakeInlineSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginSpanAccessibilityTest {
  /** The object-replacement character a plugin span draws over carries no text a screen reader can say. */
  @Test
  fun aScreenReaderHearsEachPluginSpansPlainText() {
    val text =
      SpannableString("Inline ￼ and ￼.").apply {
        setSpan(FakeInlineSpan("x^2"), 7, 8, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
        setSpan(FakeInlineSpan("y"), 13, 14, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
      }

    assertEquals(listOf("Inline plain:x^2 and plain:y."), accessibilityTextsOf(text))
  }

  /** A paragraph that is a plugin span alone holds no letter or digit of its own, yet is still read out. */
  @Test
  fun aParagraphOfOnlyAPluginSpanIsStillRead() {
    val text =
      SpannableString("￼").apply {
        setSpan(FakeInlineSpan("x^2"), 0, 1, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
      }

    assertEquals(listOf("plain:x^2"), accessibilityTextsOf(text))
  }

  /** A link makes the paragraph segmented, so the whole-text fallback never runs to bring an equation back. */
  @Test
  fun aSymbolOnlyPluginSpanBeforeALinkIsStillRead() {
    val text = render(document(paragraph(text("\uFFFC "), link("https://example.com", text("docs"))))).withSymbolSpan("+")

    assertEquals(listOf("+", "docs"), accessibilityTextsOf(text))
  }

  @Test
  fun aSymbolOnlyPluginSpanAfterALinkIsStillRead() {
    val text = render(document(paragraph(link("https://example.com", text("docs")), text(" \uFFFC")))).withSymbolSpan("=")

    assertEquals(listOf("docs", "="), accessibilityTextsOf(text))
  }

  /** Punctuation beside a link, unlike a plugin span's label, still gets no item of its own. */
  @Test
  fun punctuationBesideALinkIsNotReadOnItsOwn() {
    val text = render(document(paragraph(text("("), link("https://example.com", text("docs")), text(")."))))

    assertEquals(listOf("docs"), accessibilityTextsOf(text))
  }

  /** Puts a plugin span reading [plainText] over the text's object-replacement character. */
  private fun Spannable.withSymbolSpan(plainText: String): Spannable =
    apply {
      val index = indexOf('\uFFFC')
      setSpan(FakeInlineSpan("x", plainText = plainText), index, index + 1, SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE)
    }

  private fun accessibilityTextsOf(text: CharSequence): List<String> {
    val view = EnrichedMarkdownInternalText(ApplicationProvider.getApplicationContext())
    view.setText(text)
    view.measure(
      MeasureSpec.makeMeasureSpec(1000, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)

    val provider = view.accessibilityHelper.getAccessibilityNodeProvider(view)!!
    val host = provider.createAccessibilityNodeInfo(-1)!!
    return (0 until host.childCount).map { id ->
      provider.createAccessibilityNodeInfo(id)!!.text.toString()
    }
  }
}
