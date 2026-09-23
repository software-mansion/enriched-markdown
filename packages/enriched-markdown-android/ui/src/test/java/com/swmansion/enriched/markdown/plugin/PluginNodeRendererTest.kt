@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.latexDisplay
import com.swmansion.enriched.markdown.test.TestAstFactory.latexInline
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginNodeRendererTest {
  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun pluginNodeRendererOverridesTheBuiltIn() {
    EnrichedMarkdownPlugins.install(FakePlugin())

    val rendered = render(document(paragraph(latexInline("x^2")))).toString()

    assertTrue(rendered, rendered.contains("[fake:x^2:"))
    assertFalse(rendered, rendered.contains("\$x^2\$"))
  }

  @Test
  fun withNoPluginInlineLatexRendersItsRawSource() {
    val rendered = render(document(paragraph(text("a "), latexInline("x^2"), text(" b")))).toString()

    assertEquals("a \$x^2\$ b", rendered)
  }

  @Test
  fun withNoPluginDisplayLatexRendersItsRawSource() {
    val inParagraph = render(document(paragraph(latexDisplay("x^2")))).toString()
    assertEquals("\$\$x^2\$\$", inParagraph)

    // Promoted to a top level node there is no enclosing block style to inherit; still no crash.
    val topLevel = render(document(latexDisplay("x^2"))).toString()
    assertEquals("\$\$x^2\$\$", topLevel)
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

  @Test
  fun reinstallingAnIdReplacesItsRegistrationsRatherThanAddingToThem() {
    EnrichedMarkdownPlugins.install(FakePlugin(marker = "first"))
    EnrichedMarkdownPlugins.install(FakePlugin(marker = "second"))

    val rendered = render(document(paragraph(latexInline("x")))).toString()

    assertTrue(rendered, rendered.contains("[second:x:"))
    assertFalse(rendered, rendered.contains("first"))
  }

  @Test
  fun theLastPluginToClaimANodeTypeWins() {
    EnrichedMarkdownPlugins.install(FakePlugin(id = "a", marker = "a"))
    EnrichedMarkdownPlugins.install(FakePlugin(id = "b", marker = "b"))

    assertTrue(render(document(paragraph(latexInline("x")))).toString().contains("[b:x:"))
  }

  @Test
  fun uninstallRestoresTheBuiltInRenderer() {
    EnrichedMarkdownPlugins.install(FakePlugin())
    assertTrue(EnrichedMarkdownPlugins.isInstalled(FakePlugin.ID))

    EnrichedMarkdownPlugins.uninstall(FakePlugin.ID)

    assertFalse(EnrichedMarkdownPlugins.isInstalled(FakePlugin.ID))
    assertEquals("\$x\$", render(document(paragraph(latexInline("x")))).toString())
  }
}
