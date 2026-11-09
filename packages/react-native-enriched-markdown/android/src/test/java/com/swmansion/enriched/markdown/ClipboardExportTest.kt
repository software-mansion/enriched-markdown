package com.swmansion.enriched.markdown

import android.text.Layout
import android.text.SpannableString
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.utils.common.serialization.MarkdownASTSerializer
import com.swmansion.enriched.markdown.utils.text.conversion.HTMLGenerator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class ClipboardExportTest {
  private val context = RuntimeEnvironment.getApplication()

  @Test
  fun tableLineBreaksAreExportedAsHtmlBreaks() {
    for (separator in listOf("\n", "\r", "\r\n", "\u2028", "\u2029")) {
      for (text in listOf<CharSequence>(SpannableString("first${separator}second"), "first${separator}second")) {
        val rows = listOf(listOf(Triple(text, false, Layout.Alignment.ALIGN_NORMAL)))
        val html = HTMLGenerator.generateTableHTML(rows, style())
        assertTrue(html, html.contains("first<br>second"))
        assertFalse(html, html.contains("<br><br>"))
      }
    }
  }

  @Test
  fun escapedCharactersAndLineBreaksShareOneRun() {
    val rows = listOf(listOf(Triple<CharSequence, Boolean, Layout.Alignment>("a & b\nc <d>", false, Layout.Alignment.ALIGN_NORMAL)))
    val html = HTMLGenerator.generateTableHTML(rows, style())
    assertTrue(html, html.contains("a &amp; b<br>c &lt;d&gt;"))
  }

  @Test
  fun codeBlockNewlinesRemainLiteral() {
    val style = style()
    val codeBlock =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.CodeBlock,
        content = "first\nsecond",
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, "first\nsecond")),
      )
    val renderer = Renderer()
    renderer.configure(style, context)
    val html = HTMLGenerator.generateHTML(renderer.renderContent(listOf(codeBlock)), style)
    assertFalse(html, html.contains("<br>"))
    assertTrue(html, html.contains("first\nsecond"))
  }

  @Test
  fun serializedTableFormulaKeepsItsInlineDelimiters() {
    val formula =
      MarkdownASTNode(MarkdownASTNode.NodeType.LatexMathInline, children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, "x_1")))
    val cell = MarkdownASTNode(MarkdownASTNode.NodeType.TableCell, children = listOf(formula))
    assertEquals("\$x_1\$", MarkdownASTSerializer.serializeChildren(cell))

    val strong = MarkdownASTNode(MarkdownASTNode.NodeType.Strong, children = listOf(formula))
    val nestedCell = MarkdownASTNode(MarkdownASTNode.NodeType.TableCell, children = listOf(strong))
    assertEquals("**\$x_1\$**", MarkdownASTSerializer.serializeChildren(nestedCell))
  }

  private fun style() = StyleConfig(MarkdownRenderTestSupport.exportStyleMap(), context, false, 0f)
}
