@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.math.test.MathTestSupport.context
import com.swmansion.enriched.markdown.math.test.MathTestSupport.defaultStyle
import com.swmansion.enriched.markdown.math.test.MathTestSupport.document
import com.swmansion.enriched.markdown.math.test.MathTestSupport.latexMathDisplay
import com.swmansion.enriched.markdown.math.test.MathTestSupport.paragraph
import com.swmansion.enriched.markdown.math.test.MathTestSupport.text
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.segments.MarkdownSegment
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/**
 * Covers how display math is claimed and signed. The RaTeX engine's native library is not loadable
 * under Robolectric, so every parse here fails - which the payload records without affecting how
 * the segment is signed - and nothing lays out or draws an equation.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MathBlockSegmentTest {
  private val plugins = PluginSnapshot.of(LatexMathPlugin)

  @Test
  fun documentLevelDisplayMathBecomesItsOwnSegmentWithThePlugin() {
    val doc = document(paragraph(text("Before")), latexMathDisplay("E = mc^2"), paragraph(text("After")))

    val segments = splitASTIntoSegments(doc, plugins)

    assertEquals(3, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
    val custom = segments[1] as MarkdownSegment.Custom
    assertEquals(LatexMathPlugin.ID, custom.pluginId)
    assertTrue(custom.plugin is MathBlockSegment)
    assertEquals(doc.children[1], custom.node)
    assertTrue(segments[2] is MarkdownSegment.Text)
  }

  @Test
  fun withoutThePluginDisplayMathStaysRawTextInTheSurroundingSegment() {
    val doc = document(paragraph(text("Before")), latexMathDisplay("E = mc^2"))

    val segments = splitASTIntoSegments(doc, PluginSnapshot.EMPTY)

    assertEquals(1, segments.size)
    val rendered = MarkdownSegmentRenderer.render(segments, defaultStyle, context, plugins = PluginSnapshot.EMPTY).single()
    assertTrue((rendered as RenderedSegment.Text).styledText.toString().contains("\$\$E = mc^2\$\$"))
  }

  @Test
  fun thePayloadCarriesTheLatexAsItsSignatureSource() {
    val rendered = renderSegmentsOf(document(latexMathDisplay("E = mc^2"))).single()

    assertEquals("E = mc^2", (rendered as RenderedSegment.Custom<*>).payload.signatureSource)
    assertEquals(LatexMathPlugin.ID, rendered.pluginId)
  }

  @Test
  fun theSignatureFollowsTheLatexAndDiffersFromATextSegment() {
    val first = renderSegmentsOf(document(latexMathDisplay("x^2"))).single()
    val same = renderSegmentsOf(document(latexMathDisplay("x^2"))).single()
    val other = renderSegmentsOf(document(latexMathDisplay("x^3"))).single()
    val asText = renderSegmentsOf(document(paragraph(text("x^2")))).single()

    assertEquals(first.signature, same.signature)
    assertNotEquals(first.signature, other.signature)
    assertNotEquals(first.signature, asText.signature)
  }

  @Test
  fun latexWithNoEquationInItFallsBackToShowingItsSource() {
    val rendered = renderSegmentsOf(document(latexMathDisplay("   "))).single()

    assertEquals("\$\$   \$\$", (rendered as RenderedSegment.Text).styledText.toString())
  }

  private fun renderSegmentsOf(doc: MarkdownASTNode): List<RenderedSegment> =
    MarkdownSegmentRenderer.render(splitASTIntoSegments(doc, plugins), defaultStyle, context, plugins = plugins)
}
