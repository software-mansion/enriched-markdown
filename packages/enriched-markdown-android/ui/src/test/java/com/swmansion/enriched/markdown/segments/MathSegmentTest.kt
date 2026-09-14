package com.swmansion.enriched.markdown.segments

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.MathInlineSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathDisplay
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathInline
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Covers the math pipeline up to, but not including, the RaTeX engine: its native library
 * isn't loadable under Robolectric, so nothing here lays out or draws an equation.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MathSegmentTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  @Test
  fun splitASTIntoSegmentsPromotesDocumentLevelDisplayMathToMathSegment() {
    val display = latexMathDisplay("E = mc^2")
    val doc = document(paragraph(text("Before")), display, paragraph(text("After")))

    val segments = splitASTIntoSegments(doc)

    assertEquals(3, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
    assertEquals(MarkdownSegment.Math("E = mc^2", display), segments[1])
    assertTrue(segments[2] is MarkdownSegment.Text)
  }

  @Test
  fun inlineMathStaysInsideTextSegment() {
    val doc = document(paragraph(text("Energy "), latexMathInline("E = mc^2")))

    val segments = splitASTIntoSegments(doc)

    assertEquals(1, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
  }

  @Test
  fun mathSignatureFollowsLatexSource() {
    fun signatureOf(latex: String): Long {
      val segment = MarkdownSegment.Math(latex, latexMathDisplay(latex))
      val rendered = MarkdownSegmentRenderer.render(listOf(segment), defaultStyle, context).single()
      return (rendered as RenderedSegment.Math).signature
    }

    assertEquals(signatureOf("x^2"), signatureOf("x^2"))
    assertNotEquals(signatureOf("x^2"), signatureOf("x^3"))
  }

  @Test
  fun mathSignatureDiffersFromTextSignature() {
    val rendered =
      MarkdownSegmentRenderer.render(
        listOf(MarkdownSegment.Text(listOf(paragraph(text("x")))), MarkdownSegment.Math("x", latexMathDisplay("x"))),
        defaultStyle,
        context,
      )

    assertNotEquals(rendered[0].signature, rendered[1].signature)
  }

  @Test
  fun inlineMathRendersAsSpanOverObjectReplacementCharacter() {
    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    val spans = styled.getSpans(0, styled.length, MathInlineSpan::class.java)

    assertEquals(1, spans.size)
    assertEquals("\\pi r^2", spans[0].latex)
    assertEquals("￼", styled.substring(styled.getSpanStart(spans[0]), styled.getSpanEnd(spans[0])))
  }

  @Test
  fun inlineMathFontSizeFollowsEnclosingBlock() {
    val styled = render(document(paragraph(latexMathInline("x"))))

    val span = styled.getSpans(0, styled.length, MathInlineSpan::class.java).single()

    assertEquals(defaultStyle.paragraphStyle.fontSize, span.fontSize, 0.01f)
  }

  @Test
  fun markdownExtractionWrapsInlineMathInDollarDelimiters() {
    val styled = render(document(paragraph(text("Area: "), latexMathInline("\\pi r^2"))))

    val markdown = MarkdownExtractor.extractFromSpannable(styled, 0, styled.length)

    assertEquals("Area: \$\\pi r^2\$", markdown)
  }
}
