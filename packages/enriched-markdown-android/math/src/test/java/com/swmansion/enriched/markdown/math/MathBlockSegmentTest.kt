@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.context
import com.swmansion.enriched.markdown.math.test.MathTestSupport.defaultStyle
import com.swmansion.enriched.markdown.math.test.MathTestSupport.document
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexDisplay
import com.swmansion.enriched.markdown.math.test.MathTestSupport.paragraph
import com.swmansion.enriched.markdown.math.test.MathTestSupport.text
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.segments.MarkdownSegment
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Covers the math pipeline up to, but not including, the RaTeX engine: its native library is not
 * loadable under Robolectric, so nothing here lays out or draws an equation.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MathBlockSegmentTest {
  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun documentLevelDisplayMathBecomesItsOwnSegmentOnceThePluginIsInstalled() {
    EnrichedMarkdownPlugins.install(LatexMathPlugin)
    val doc = document(paragraph(text("Before")), latexDisplay("E = mc^2"), paragraph(text("After")))

    val segments = splitASTIntoSegments(doc)

    assertEquals(3, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
    assertEquals(MarkdownSegment.Custom(LatexMathPlugin.ID, doc.children[1]), segments[1])
    assertTrue(segments[2] is MarkdownSegment.Text)
  }

  @Test
  fun withoutThePluginDisplayMathStaysRawTextInTheSurroundingSegment() {
    val doc = document(paragraph(text("Before")), latexDisplay("E = mc^2"))

    val segments = splitASTIntoSegments(doc)

    assertEquals(1, segments.size)
    val rendered = MarkdownSegmentRenderer.render(segments, defaultStyle, context).single()
    assertTrue((rendered as RenderedSegment.Text).styledText.toString().contains("\$\$E = mc^2\$\$"))
  }

  @Test
  fun thePayloadCarriesTheLatexAsItsSignatureSource() {
    EnrichedMarkdownPlugins.install(LatexMathPlugin)

    val rendered = renderSegmentsOf(document(latexDisplay("E = mc^2"))).single()

    assertEquals("E = mc^2", (rendered as RenderedSegment.Custom).payload.signatureSource)
    assertEquals(LatexMathPlugin.ID, rendered.pluginId)
  }

  @Test
  fun theSignatureFollowsTheLatexAndDiffersFromATextSegment() {
    EnrichedMarkdownPlugins.install(LatexMathPlugin)

    val first = renderSegmentsOf(document(latexDisplay("x^2"))).single()
    val same = renderSegmentsOf(document(latexDisplay("x^2"))).single()
    val other = renderSegmentsOf(document(latexDisplay("x^3"))).single()
    val asText = renderSegmentsOf(document(paragraph(text("x^2")))).single()

    assertEquals(first.signature, same.signature)
    assertNotEquals(first.signature, other.signature)
    assertNotEquals(first.signature, asText.signature)
  }

  @Test
  fun latexWithNoEquationInItFallsBackToShowingItsSource() {
    EnrichedMarkdownPlugins.install(LatexMathPlugin)

    val rendered = renderSegmentsOf(document(latexDisplay("   "))).single()

    assertEquals("\$\$   \$\$", (rendered as RenderedSegment.Text).styledText.toString())
  }

  private fun renderSegmentsOf(doc: MarkdownASTNode): List<RenderedSegment> =
    MarkdownSegmentRenderer.render(splitASTIntoSegments(doc), defaultStyle, context)
}
