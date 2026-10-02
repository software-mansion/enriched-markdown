@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.segments.MarkdownSegment
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.test.FakeBlockSegment
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathDisplay
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** Every test hands the pipeline its own snapshot, so none touches the process-wide registry. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginBlockSegmentTest {
  private val context: Context = ApplicationProvider.getApplicationContext()
  private val plugin = FakePlugin()
  private val plugins = PluginSnapshot.of(plugin)

  @Test
  fun aClaimedNodeBecomesItsOwnSegmentAndFlushesTheTextAroundIt() {
    val doc =
      document(
        paragraph(text("before")),
        latexMathDisplay("x^2"),
        paragraph(text("after")),
      )

    val segments = splitASTIntoSegments(doc, plugins)

    assertEquals(3, segments.size)
    assertEquals(listOf(doc.children[0]), (segments[0] as MarkdownSegment.Text).nodes)
    val custom = segments[1] as MarkdownSegment.Custom
    assertEquals(FakePlugin.ID, custom.pluginId)
    assertSame(plugin.blockSegment, custom.plugin)
    assertEquals(doc.children[1], custom.node)
    assertEquals(listOf(doc.children[2]), (segments[2] as MarkdownSegment.Text).nodes)
  }

  @Test
  fun anUnclaimedNodeStaysInsideTheTextSegment() {
    val doc = document(paragraph(text("before")), latexMathDisplay("x^2"))

    val segments = splitASTIntoSegments(doc, PluginSnapshot.EMPTY)

    assertEquals(1, segments.size)
    assertEquals(doc.children, (segments[0] as MarkdownSegment.Text).nodes)
  }

  @Test
  fun aPluginClaimWinsOverCoresTableSegment() {
    val table = MarkdownASTNode(NodeType.Table)
    val claimsTables = PluginSnapshot.of(TwoSegmentPlugin(NodeType.Table))

    val segments = splitASTIntoSegments(document(table), claimsTables)

    assertEquals(table, (segments.single() as MarkdownSegment.Custom).node)
  }

  @Test
  fun renderAsksTheOwningPluginForItsPayload() {
    val rendered = render(document(latexMathDisplay("x^2")))

    val custom = rendered.single() as RenderedSegment.Custom<*>
    assertEquals(FakePlugin.ID, custom.pluginId)
    assertSame(plugin.blockSegment, custom.plugin)
    assertEquals("fake:x^2", custom.payload.signatureSource)
  }

  @Test
  fun aNullPayloadFallsBackToTextRenderingInsteadOfDroppingTheNode() {
    val rendered = render(document(latexMathDisplay(FakePlugin.DECLINE)))

    val fallback = rendered.single() as RenderedSegment.Text
    assertEquals("\$\$${FakePlugin.DECLINE}\$\$", fallback.styledText.toString())
  }

  @Test
  fun withoutAClaimTheNodeRendersAsText() {
    val rendered = render(document(latexMathDisplay("x^2")), PluginSnapshot.EMPTY)

    assertTrue(rendered.single() is RenderedSegment.Text)
  }

  /** Segments keep the instance that claimed them, so one plugin may register several. */
  @Test
  fun onePluginCanOwnSeveralBlockSegmentImplementations() {
    val twoSegments = TwoSegmentPlugin(NodeType.CodeBlock)
    val doc = document(latexMathDisplay("x"), MarkdownASTNode(NodeType.CodeBlock, content = "y"))

    val rendered = render(doc, PluginSnapshot.of(twoSegments)).map { it as RenderedSegment.Custom<*> }

    assertSame(twoSegments.latex, rendered[0].plugin)
    assertSame(twoSegments.other, rendered[1].plugin)
    assertEquals(listOf("latex:x", "other:y"), rendered.map { it.payload.signatureSource })
  }

  @Test
  fun signaturesAreStableForIdenticalContentAndUniquePerPayloadAndKind() {
    val first = render(document(latexMathDisplay("x^2"))).single()
    val same = render(document(latexMathDisplay("x^2"))).single()
    val other = render(document(latexMathDisplay("y^2"))).single()
    val asText = render(document(latexMathDisplay("x^2")), PluginSnapshot.EMPTY).single()

    assertEquals(first.signature, same.signature)
    assertNotEquals(first.signature, other.signature)
    assertNotEquals(first.signature, asText.signature)
  }

  @Test
  fun theOwningPluginIdSaltsTheSignature() {
    val fromA = render(document(latexMathDisplay("x")), PluginSnapshot.of(FakePlugin(id = "a", marker = "shared"))).single()
    val fromB = render(document(latexMathDisplay("x")), PluginSnapshot.of(FakePlugin(id = "b", marker = "shared"))).single()

    assertEquals("shared:x", (fromA as RenderedSegment.Custom<*>).payload.signatureSource)
    assertEquals("shared:x", (fromB as RenderedSegment.Custom<*>).payload.signatureSource)
    assertNotEquals(fromA.signature, fromB.signature)
  }

  private fun render(
    doc: MarkdownASTNode,
    snapshot: PluginSnapshot = plugins,
  ): List<RenderedSegment> = MarkdownSegmentRenderer.render(splitASTIntoSegments(doc, snapshot), defaultStyle, context, plugins = snapshot)

  private class TwoSegmentPlugin(
    private val otherType: NodeType,
  ) : MarkdownPlugin {
    val latex = FakeBlockSegment(marker = "latex")
    val other = FakeBlockSegment(marker = "other")

    override val id: String = "two"

    override fun install(registry: PluginRegistry) {
      registry.registerBlockSegment(NodeType.LatexMathDisplay, latex)
      registry.registerBlockSegment(otherType, other)
    }
  }
}
