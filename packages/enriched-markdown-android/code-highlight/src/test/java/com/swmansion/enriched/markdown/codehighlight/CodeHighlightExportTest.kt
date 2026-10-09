package com.swmansion.enriched.markdown.codehighlight

import android.text.Spannable
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.blockquote
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.codeBlock
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.context
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.defaultStyle
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.document
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.listItem
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.paragraph
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.pluginWith
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.render
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.text
import com.swmansion.enriched.markdown.codehighlight.test.CodeHighlightTestSupport.unorderedList
import com.swmansion.enriched.markdown.codehighlight.test.FakeTokenSource
import com.swmansion.enriched.markdown.codehighlight.test.FakeTokenSource.Companion.CODE
import com.swmansion.enriched.markdown.codehighlight.test.FakeTokenSource.Companion.LANGUAGE
import com.swmansion.enriched.markdown.utils.text.conversion.HTMLGenerator
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Copy as Markdown and HTML export read spans, and token spans split a block into many span runs.
 * Neither may change what they produce: highlighting is display-only, as on iOS.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class CodeHighlightExportTest {
  private val doc =
    document(
      paragraph(text("Intro")),
      codeBlock(CODE, LANGUAGE),
      unorderedList(listItem(paragraph(text("item")), codeBlock(CODE, LANGUAGE))),
      blockquote(codeBlock(CODE, LANGUAGE)),
    )

  private val plain by lazy { render(doc) }
  private val highlighted by lazy { render(doc, plugins = pluginWith(FakeTokenSource())) }

  @Test
  fun theHighlightedRenderCarriesTokenSpans() {
    assertEquals(plain.toString(), highlighted.toString())
    assertTrue(highlighted.getSpans(0, highlighted.length, SyntaxTokenSpan::class.java).size >= 3 * 5)
  }

  @Test
  fun copyAsMarkdownIsUnchanged() {
    assertEquals(markdown(plain, 0, plain.length), markdown(highlighted, 0, highlighted.length))

    // A selection starting and ending inside tokens.
    val start = plain.indexOf("greet") + 2
    val end = plain.lastIndexOf("say") + 1
    assertEquals(markdown(plain, start, end), markdown(highlighted, start, end))
  }

  @Test
  fun htmlExportIsUnchanged() {
    assertEquals(html(plain), html(highlighted))
  }

  private fun markdown(
    text: Spannable,
    start: Int,
    end: Int,
  ): String = MarkdownExtractor.extractFromSpannable(text, start, end)

  private fun html(text: Spannable): String {
    val metrics = context.resources.displayMetrics
    return HTMLGenerator.generateHTML(text, defaultStyle, metrics.scaledDensity, metrics.density)
  }
}
