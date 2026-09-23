@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.segments.MarkdownSegment
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.latexDisplay
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginBlockSegmentTest {
  private val context: Context = ApplicationProvider.getApplicationContext()
  private val claimed = mapOf(NodeType.LatexMathDisplay to FakePlugin.ID)

  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun aClaimedNodeBecomesItsOwnSegmentAndFlushesTheTextAroundIt() {
    val doc =
      document(
        paragraph(text("before")),
        latexDisplay("x^2"),
        paragraph(text("after")),
      )

    val segments = splitASTIntoSegments(doc, claimed)

    assertEquals(3, segments.size)
    assertEquals(listOf(doc.children[0]), (segments[0] as MarkdownSegment.Text).nodes)
    val custom = segments[1] as MarkdownSegment.Custom
    assertEquals(FakePlugin.ID, custom.pluginId)
    assertEquals(doc.children[1], custom.node)
    assertEquals(listOf(doc.children[2]), (segments[2] as MarkdownSegment.Text).nodes)
  }

  @Test
  fun anUnclaimedNodeStaysInsideTheTextSegment() {
    val doc = document(paragraph(text("before")), latexDisplay("x^2"))

    val segments = splitASTIntoSegments(doc, emptyMap())

    assertEquals(1, segments.size)
    assertEquals(doc.children, (segments[0] as MarkdownSegment.Text).nodes)
  }

  @Test
  fun renderAsksTheOwningPluginForItsPayload() {
    EnrichedMarkdownPlugins.install(FakePlugin())

    val rendered = render(splitASTIntoSegments(document(latexDisplay("x^2")), claimed))

    val custom = rendered.single() as RenderedSegment.Custom
    assertEquals(FakePlugin.ID, custom.pluginId)
    assertEquals("fake:x^2", custom.payload.signatureSource)
  }

  @Test
  fun aNullPayloadFallsBackToTextRenderingInsteadOfDroppingTheNode() {
    EnrichedMarkdownPlugins.install(FakePlugin())

    val rendered = render(splitASTIntoSegments(document(latexDisplay(FakePlugin.DECLINE)), claimed))

    val fallback = rendered.single() as RenderedSegment.Text
    assertEquals("\$\$${FakePlugin.DECLINE}\$\$", fallback.styledText.toString())
  }

  @Test
  fun anUninstalledPluginFallsBackToTextRendering() {
    val rendered = render(splitASTIntoSegments(document(latexDisplay("x^2")), claimed))

    assertTrue(rendered.single() is RenderedSegment.Text)
  }

  @Test
  fun signaturesAreStableForIdenticalContentAndUniquePerPayloadAndKind() {
    EnrichedMarkdownPlugins.install(FakePlugin())

    val first = render(splitASTIntoSegments(document(latexDisplay("x^2")), claimed)).single()
    val same = render(splitASTIntoSegments(document(latexDisplay("x^2")), claimed)).single()
    val other = render(splitASTIntoSegments(document(latexDisplay("y^2")), claimed)).single()
    val asText = render(splitASTIntoSegments(document(latexDisplay("x^2")), emptyMap())).single()

    assertEquals(first.signature, same.signature)
    assertNotEquals(first.signature, other.signature)
    assertNotEquals(first.signature, asText.signature)
  }

  @Test
  fun theOwningPluginIdSaltsTheSignature() {
    EnrichedMarkdownPlugins.install(FakePlugin(id = "a", marker = "shared"))
    val fromA = render(splitASTIntoSegments(document(latexDisplay("x")), mapOf(NodeType.LatexMathDisplay to "a"))).single()

    EnrichedMarkdownPlugins.reset()
    EnrichedMarkdownPlugins.install(FakePlugin(id = "b", marker = "shared"))
    val fromB = render(splitASTIntoSegments(document(latexDisplay("x")), mapOf(NodeType.LatexMathDisplay to "b"))).single()

    assertEquals("shared:x", (fromA as RenderedSegment.Custom).payload.signatureSource)
    assertEquals("shared:x", (fromB as RenderedSegment.Custom).payload.signatureSource)
    assertNotEquals(fromA.signature, fromB.signature)
  }

  private fun render(segments: List<MarkdownSegment>): List<RenderedSegment> =
    MarkdownSegmentRenderer.render(segments, defaultStyle, context)
}
