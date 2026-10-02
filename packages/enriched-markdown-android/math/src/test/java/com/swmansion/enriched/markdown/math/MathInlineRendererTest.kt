@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.defaultStyle
import com.swmansion.enriched.markdown.math.test.MathTestSupport.document
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexMathDisplay
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexMathInline
import com.swmansion.enriched.markdown.math.test.MathTestSupport.paragraph
import com.swmansion.enriched.markdown.math.test.MathTestSupport.render
import com.swmansion.enriched.markdown.math.test.MathTestSupport.text
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * The inline half of the plugin. The RaTeX engine cannot load under Robolectric, so the spans built
 * here all hold a failed layout and draw their source; what they carry is still checked.
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
  fun inlineMathRendersAsOneSpanOverTheObjectReplacementCharacter() {
    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    val span = styled.getSpans(0, styled.length, MathInlineSpan::class.java).single()

    assertEquals("\\pi r^2", span.latex)
    assertEquals("￼", styled.substring(styled.getSpanStart(span), styled.getSpanEnd(span)))
  }

  @Test
  fun inlineMathFontSizeFollowsTheEnclosingBlock() {
    val styled = render(document(paragraph(latexMathInline("x"))))

    val span = styled.getSpans(0, styled.length, MathInlineSpan::class.java).single()

    assertEquals(defaultStyle.paragraphStyle.fontSize, span.fontSize, 0.01f)
  }

  @Test
  fun withoutThePluginInlineMathStaysItsOwnSource() {
    EnrichedMarkdownPlugins.reset()

    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    assertEquals(0, styled.getSpans(0, styled.length, MathInlineSpan::class.java).size)
    assertEquals("Area: \$\\pi r^2\$", styled.toString())
  }

  /** Core owns the extraction; the span owns the delimiters. */
  @Test
  fun markdownExtractionWrapsInlineMathInDollarDelimiters() {
    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    val markdown = MarkdownExtractor.extractFromSpannable(styled, 0, styled.length)

    assertEquals("Area: \$\\pi r^2\$", markdown)
  }

  /** Typeset inline, but copied back out as the display math it was written as. */
  @Test
  fun midLineDisplayMathKeepsItsDoubleDollarDelimiters() {
    val styled = render(document(paragraph(text("Energy: "), latexMathDisplay("E = mc^2"))))

    val span = styled.getSpans(0, styled.length, MathInlineSpan::class.java).single()
    val markdown = MarkdownExtractor.extractFromSpannable(styled, 0, styled.length)

    assertTrue(span.displayMode)
    assertEquals("Energy: \$\$E = mc^2\$\$", markdown)
  }

  /** HTML export wraps this in core's inline-code styling, so the `$` must not be repeated here. */
  @Test
  fun htmlTextIsTheBareLatex() {
    val span = MathInlineSpan.layOut(latex = "x^2", fontSize = 16f, textColor = 0)

    assertEquals("x^2", span.toHtmlText())
    assertEquals("\$x^2\$", span.toMarkdownSource())
  }
}
