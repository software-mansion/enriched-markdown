package com.swmansion.enriched.markdown

import android.graphics.Color
import android.text.Layout
import android.text.SpannableString
import com.facebook.react.bridge.JavaOnlyMap
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.styles.StyleConfig
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

  private fun style(): StyleConfig {
    com.facebook.react.uimanager.DisplayMetricsHolder
      .initDisplayMetricsIfNotInitialized(context)

    fun element() =
      JavaOnlyMap().apply {
        listOf(
          "aspectRatio",
          "bulletSize",
          "checkboxBorderRadius",
          "checkboxSize",
          "height",
          "itemSpacing",
          "markerMinWidth",
          "maxHeight",
          "cellPaddingHorizontal",
          "cellPaddingVertical",
          "horizontalOverflow",
          "lineHeight",
          "marginTop",
          "marginBottom",
          "padding",
          "borderRadius",
          "borderWidth",
          "gapWidth",
          "marginLeft",
        ).forEach {
          putDouble(it, 0.0)
        }
        listOf(
          "bulletColor",
          "checkedColor",
          "checkedTextColor",
          "checkmarkColor",
          "headerBackgroundColor",
          "headerTextColor",
          "markerColor",
          "rowEvenBackgroundColor",
          "rowOddBackgroundColor",
          "color",
          "borderColor",
        ).forEach {
          putInt(it, Color.BLACK)
        }
        putString("resizeMode", "contain")
        putString("fontFamily", "")
        putString("fontWeight", "normal")
        putDouble("fontSize", 16.0)
        putDouble("fontScale", 0.8)
        putDouble("baselineOffsetScale", 0.5)
        putBoolean("underline", false)
        putInt("backgroundColor", Color.TRANSPARENT)
      }
    val style = JavaOnlyMap()
    listOf(
      "table",
      "paragraph",
      "codeBlock",
      "code",
      "blockquote",
      "list",
      "link",
      "strong",
      "em",
      "strikethrough",
      "underline",
      "highlight",
      "image",
      "superscript",
      "subscript",
    ).forEach { style.putMap(it, element()) }
    style.putMap(
      "spoiler",
      element().apply {
        putMap("particles", JavaOnlyMap.of("density", 0.5, "speed", 1.0))
        putMap("solid", JavaOnlyMap.of("borderRadius", 0.0))
      },
    )
    for (level in 1..6) style.putMap("h$level", element())
    style.putMap(
      "taskList",
      JavaOnlyMap.of(
        "checkedColor",
        Color.BLACK,
        "borderColor",
        Color.BLACK,
        "checkmarkColor",
        Color.BLACK,
        "checkedTextColor",
        Color.BLACK,
        "checkboxSize",
        16.0,
        "checkboxBorderRadius",
        0.0,
        "checkedStrikethrough",
        false,
      ),
    )
    return StyleConfig(style, context, false, 0f)
  }
}
