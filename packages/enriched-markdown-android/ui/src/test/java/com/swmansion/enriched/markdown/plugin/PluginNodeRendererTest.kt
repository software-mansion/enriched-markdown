@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.text.SpannableStringBuilder
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererFactory
import com.swmansion.enriched.markdown.renderer.latexSourceOf
import com.swmansion.enriched.markdown.spans.TextSpan
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathDisplay
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathInline
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginNodeRendererTest {
  // The registry is process-wide and the first render anywhere freezes it.
  @Before
  fun setUp() = EnrichedMarkdownPlugins.reset()

  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun pluginNodeRendererOverridesTheBuiltIn() {
    EnrichedMarkdownPlugins.install(FakePlugin())

    val rendered = render(document(paragraph(latexMathInline("x^2")))).toString()

    assertTrue(rendered, rendered.contains("[fake:x^2:"))
    assertFalse(rendered, rendered.contains("\$x^2\$"))
  }

  @Test
  fun withNoPluginInlineLatexRendersItsRawSource() {
    val rendered = render(document(paragraph(text("a "), latexMathInline("x^2"), text(" b")))).toString()

    assertEquals("a \$x^2\$ b", rendered)
  }

  @Test
  fun withNoPluginDisplayLatexRendersItsRawSource() {
    val inParagraph = render(document(paragraph(latexMathDisplay("x^2")))).toString()
    assertEquals("\$\$x^2\$\$", inParagraph)

    // Promoted to a top level node there is no enclosing block style to inherit; still no crash.
    val topLevel = render(document(latexMathDisplay("x^2"))).toString()
    assertEquals("\$\$x^2\$\$", topLevel)
  }

  /** A top-level equation is a block of its own, so the paragraph after it starts on a new line. */
  @Test
  fun withNoPluginTopLevelDisplayLatexIsAParagraphOfItsOwn() {
    val rendered =
      render(document(paragraph(text("Energy follows")), latexMathDisplay("E=mc^2"), paragraph(text("and this is why"))))

    assertEquals("Energy follows\n\$\$E=mc^2\$\$\nand this is why", rendered.toString())
    val sourceStart = rendered.indexOf("\$\$")
    assertTrue(rendered.getSpans(sourceStart, sourceStart + 1, TextSpan::class.java).isNotEmpty())
  }

  @Test
  fun latexIsTakenFromChildrenWhenTheNodeCarriesNoContent() {
    val node =
      MarkdownASTNode(
        type = MarkdownASTNode.NodeType.LatexMathInline,
        children = listOf(text("a"), MarkdownASTNode(MarkdownASTNode.NodeType.SoftBreak), text("b")),
      )

    assertEquals("\$a b\$", render(document(paragraph(node))).toString())
  }

  /** `$$` on lines of its own: md4c hands the breaks after the opening and before the closing over too. */
  @Test
  fun breaksAgainstTheDelimitersAreNotPartOfTheLatex() {
    val softBreak = MarkdownASTNode(MarkdownASTNode.NodeType.SoftBreak)
    val node =
      MarkdownASTNode(
        type = MarkdownASTNode.NodeType.LatexMathDisplay,
        children = listOf(softBreak, text("E=mc^2"), softBreak),
      )

    assertEquals("E=mc^2", latexSourceOf(node))
    assertEquals("x", latexSourceOf(latexMathDisplay("  x\n")))
  }

  @Test
  fun aTrailingControlSpaceKeepsItsSpace() {
    assertEquals("a\\ ", latexSourceOf(latexMathInline("a\\ ")))
    assertEquals("a\\\\", latexSourceOf(latexMathInline("a\\\\ ")))
  }

  @Test
  fun reinstallingAnIdReplacesItsRegistrationsRatherThanAddingToThem() {
    EnrichedMarkdownPlugins.install(FakePlugin(marker = "first"))
    EnrichedMarkdownPlugins.install(FakePlugin(marker = "second"))

    val rendered = render(document(paragraph(latexMathInline("x")))).toString()

    assertTrue(rendered, rendered.contains("[second:x:"))
    assertFalse(rendered, rendered.contains("first"))
  }

  @Test
  fun theLastPluginToClaimANodeTypeWins() {
    EnrichedMarkdownPlugins.install(FakePlugin(id = "a", marker = "a"))
    EnrichedMarkdownPlugins.install(FakePlugin(id = "b", marker = "b"))

    assertTrue(render(document(paragraph(latexMathInline("x")))).toString().contains("[b:x:"))
  }

  @Test
  fun aPluginCanClaimEveryCoreNodeTypeIncludingSpoilers() {
    EnrichedMarkdownPlugins.install(ClaimingPlugin(MarkdownASTNode.NodeType.Spoiler) { _, builder, _ -> builder.append("[mine]") })

    val spoiler = MarkdownASTNode(MarkdownASTNode.NodeType.Spoiler, children = listOf(text("hidden")))

    assertEquals("[mine]", render(document(paragraph(spoiler))).toString())
  }

  @Test
  fun aPluginRendererCanHandANodeBackToCore() {
    EnrichedMarkdownPlugins.install(
      ClaimingPlugin(MarkdownASTNode.NodeType.LatexMathInline) { node, builder, factory ->
        factory.builtInRenderer(node.type)!!.render(node, builder, null, null, factory)
      },
    )

    assertEquals("\$x\$", render(document(paragraph(latexMathInline("x")))).toString())
  }

  @Test
  fun anInstallAfterTheFirstRenderIsIgnored() {
    assertEquals("\$x\$", render(document(paragraph(latexMathInline("x")))).toString())

    EnrichedMarkdownPlugins.install(FakePlugin())

    assertFalse(EnrichedMarkdownPlugins.isInstalled(FakePlugin.ID))
    assertEquals("\$x\$", render(document(paragraph(latexMathInline("x")))).toString())
  }

  @Test
  fun resetLiftsTheFreeze() {
    render(document(paragraph(latexMathInline("x"))))
    EnrichedMarkdownPlugins.reset()

    EnrichedMarkdownPlugins.install(FakePlugin())

    assertTrue(EnrichedMarkdownPlugins.isInstalled(FakePlugin.ID))
    assertTrue(render(document(paragraph(latexMathInline("x")))).toString().contains("[fake:x:"))
  }

  private class ClaimingPlugin(
    private val type: MarkdownASTNode.NodeType,
    private val render: (MarkdownASTNode, SpannableStringBuilder, RendererFactory) -> Unit,
  ) : MarkdownPlugin {
    override val id: String = "claiming"

    override fun install(registry: PluginRegistry) {
      registry.registerNodeRenderer(type) { _, _ ->
        object : NodeRenderer {
          override fun render(
            node: MarkdownASTNode,
            builder: SpannableStringBuilder,
            onLinkPress: ((String) -> Unit)?,
            onLinkLongPress: ((String) -> Unit)?,
            factory: RendererFactory,
          ) = render(node, builder, factory)
        }
      }
    }
  }
}
