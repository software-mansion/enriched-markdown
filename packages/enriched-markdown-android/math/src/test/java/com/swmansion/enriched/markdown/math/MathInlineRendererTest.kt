@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.document
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexMathDisplay
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexMathInline
import com.swmansion.enriched.markdown.math.test.MathTestSupport.paragraph
import com.swmansion.enriched.markdown.math.test.MathTestSupport.render
import com.swmansion.enriched.markdown.math.test.MathTestSupport.spoiler
import com.swmansion.enriched.markdown.math.test.MathTestSupport.text
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spans.TextSpan
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The inline half of the plugin. The RaTeX engine cannot load under Robolectric, so every equation
 * here is one the engine rejects, which the renderer hands to core's source text instead of a span.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MathInlineRendererTest {
  // The registry is process-wide and the first render anywhere freezes it.
  @Before
  fun setUp() {
    EnrichedMarkdownPlugins.reset()
    EnrichedMarkdownPlugins.install(LatexMathPlugin)
  }

  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun aRejectedEquationIsCoresStyledSourceTextRatherThanASpan() {
    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    assertEquals(0, styled.getSpans(0, styled.length, MathInlineSpan::class.java).size)
    assertEquals("Area: \$\\pi r^2\$", styled.toString())
    assertTrue(styled.getSpans(6, styled.length, TextSpan::class.java).any { styled.getSpanStart(it) == 6 })
  }

  @Test
  fun aRejectedEquationIsReportedOnce() {
    val events = mutableListOf<LatexError>()

    render(document(paragraph(latexMathInline("\\pi r^2"))), onPluginEvent = { events += it as LatexError })

    assertEquals("\\pi r^2", events.single().source)
  }

  /** Being text, the fallback is concealed by the spoiler around it like any other text. */
  @Test
  fun aRejectedEquationInsideASpoilerIsConcealedWithIt() {
    val styled = render(document(paragraph(spoiler(text("the answer is "), latexMathInline("x=42")))))

    val spoilerSpan = styled.getSpans(0, styled.length, SpoilerSpan::class.java).single()

    assertEquals("the answer is \$x=42\$", styled.substring(styled.getSpanStart(spoilerSpan), styled.getSpanEnd(spoilerSpan)))
  }

  @Test
  fun withoutThePluginInlineMathStaysItsOwnSource() {
    EnrichedMarkdownPlugins.reset()

    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    assertEquals(0, styled.getSpans(0, styled.length, MathInlineSpan::class.java).size)
    assertEquals("Area: \$\\pi r^2\$", styled.toString())
  }

  @Test
  fun markdownExtractionOfARejectedEquationKeepsItsDollarDelimiters() {
    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    val markdown = MarkdownExtractor.extractFromSpannable(styled, 0, styled.length)

    assertEquals("Area: \$\\pi r^2\$", markdown)
  }

  @Test
  fun aRejectedMidLineDisplayEquationKeepsItsDoubleDollarDelimiters() {
    val styled = render(document(paragraph(text("Energy: "), latexMathDisplay("E = mc^2"))))

    val markdown = MarkdownExtractor.extractFromSpannable(styled, 0, styled.length)

    assertEquals("Energy: \$\$E = mc^2\$\$", markdown)
  }
}
