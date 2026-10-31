package com.swmansion.enriched.markdown

import android.app.Activity
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Color
import android.text.Layout
import android.text.SpannableString
import android.view.View
import android.view.ViewGroup
import android.widget.PopupWindow
import com.facebook.react.bridge.JavaOnlyMap
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.segments.TableContainerView
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.serialization.MarkdownASTSerializer
import com.swmansion.enriched.markdown.utils.text.conversion.HTMLGenerator
import com.swmansion.enriched.markdown.views.ContextMenuPopup
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
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

  // The parser does not yet turn HTML <br> into break nodes in table cells.
  // Construct them here, then exercise the real table view and its Copy actions.
  private fun node(
    type: NodeType,
    vararg children: MarkdownASTNode,
  ) = MarkdownASTNode(type, children = children.toList())

  private fun text(value: String) = MarkdownASTNode(NodeType.Text, value)

  private fun table(cell: MarkdownASTNode): MarkdownASTNode =
    node(
      NodeType.Table,
      node(
        NodeType.TableHead,
        node(NodeType.TableRow, node(NodeType.TableHeaderCell, text("Cell")), node(NodeType.TableHeaderCell, text("Empty"))),
      ),
      node(NodeType.TableBody, node(NodeType.TableRow, cell, node(NodeType.TableCell))),
    )

  private fun copyTable(
    table: MarkdownASTNode,
    asMarkdown: Boolean = false,
  ): Pair<TableContainerView, String> {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    activity.setTheme(android.R.style.Theme_Material_Light)
    val view = TableContainerView(activity, style())
    view.accessibilityLabels = AccessibilityLabels(tableRow = "Row {n}, {content}")
    activity.setContentView(view)
    view.applyTableNode(table)
    view.measure(
      View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(2000, View.MeasureSpec.AT_MOST),
    )
    view.layout(0, 0, 1000, view.measuredHeight)
    val grid = (view.getChildAt(0) as ViewGroup).getChildAt(0) as ViewGroup
    val cell = (0 until grid.childCount).map { grid.getChildAt(it) }.first { it.isLongClickable }
    assertTrue(cell.performLongClick())
    val popupField = ContextMenuPopup::class.java.getDeclaredField("activePopup").apply { isAccessible = true }
    val popup = popupField.get(null) as PopupWindow
    val menu = popup.contentView as ViewGroup
    menu.getChildAt(if (asMarkdown) 2 else 0).performClick()
    val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val clip = clipboard.primaryClip!!
    if (!asMarkdown) assertTrue(clip.getItemAt(0).htmlText!!.contains("<table"))
    return view to clip.getItemAt(0).text.toString()
  }

  @Test
  fun tableCopyPreservesHardAndSoftBreaksInPlainTextAndAccessibility() {
    for (breakType in listOf(NodeType.LineBreak, NodeType.SoftBreak)) {
      val cell =
        node(NodeType.TableCell, node(breakType), text("first"), node(NodeType.Strong, node(breakType), text("bold")), node(breakType))
      val (view, copied) = copyTable(table(cell))
      assertEquals("Cell\tEmpty\n\nfirst\nbold\n\t", copied)
      val grid = (view.getChildAt(0) as ViewGroup).getChildAt(0) as ViewGroup
      val descriptions = (0 until grid.childCount).mapNotNull { grid.getChildAt(it).contentDescription?.toString() }
      assertTrue(descriptions.toString(), descriptions.any { it.contains("\nfirst\nbold\n") })
    }
  }

  @Test
  fun tableCopyAsMarkdownKeepsBreaksWithinTheirHeaderAndBodyRows() {
    val header =
      node(
        NodeType.TableHeaderCell,
        text("first"),
        node(NodeType.LineBreak),
        node(NodeType.Emphasis, text("second"), node(NodeType.SoftBreak), text("third")),
      )
    val body =
      node(NodeType.TableCell, text("first"), node(NodeType.Strong, node(NodeType.SoftBreak), text("second")), node(NodeType.LineBreak))
    val ast =
      node(
        NodeType.Table,
        node(NodeType.TableHead, node(NodeType.TableRow, header, node(NodeType.TableHeaderCell))),
        node(NodeType.TableBody, node(NodeType.TableRow, body, node(NodeType.TableCell))),
      )
    val (_, copied) = copyTable(ast, asMarkdown = true)
    assertEquals("| first<br>*second<br>third* |  |\n| --- | --- |\n| first**<br>second**<br> |  |\n", copied)
    assertEquals(3, copied.trimEnd('\n').lines().size)
    val quote = node(NodeType.Blockquote, ast)
    assertEquals(copied.lines().dropLast(1).joinToString("") { "> $it\n" }, MarkdownASTSerializer.serializeBlockquote(quote))
  }

  @Test
  fun tableCellBreakSerializationPreservesInlineSyntax() {
    val cell =
      node(
        NodeType.TableCell,
        node(NodeType.LatexMathInline, text("x_1")),
        node(NodeType.LineBreak),
        MarkdownASTNode(
          NodeType.Link,
          attributes = mapOf("url" to "https://example.test"),
          children = listOf(node(NodeType.Strong, text("link")), node(NodeType.SoftBreak), text("label")),
        ),
        text(" \\| "),
        node(NodeType.Code, text("literal\\n<br>")),
      )
    // RaTeX's Android native library cannot load in the host JVM. Check math
    // through the same cell serializer, and copy the remaining inline nodes via the view.
    assertEquals("\$x_1\$<br>[**link**<br>label](https://example.test) \\| `literal\\n<br>`", MarkdownASTSerializer.serializeChildren(cell))
    val withoutMath = cell.copy(children = cell.children.drop(2))
    assertEquals(
      "| Cell | Empty |\n| --- | --- |\n| [**link**<br>label](https://example.test) \\| `literal\\n<br>` |  |\n",
      copyTable(table(withoutMath), asMarkdown = true).second,
    )
  }

  @Test
  fun tableCellLiteralContentIsNotRewritten() {
    // Only break nodes change. Literal newlines, including code content, are not rewritten as HTML.
    val literal = node(NodeType.TableCell, text("a\nb"), node(NodeType.Code, text("c\nd")))
    assertEquals("a\nb`c\nd`", MarkdownASTSerializer.serializeChildren(literal))
  }

  @Test
  fun paragraphAndCodeBlockBreakSerializationIsUnchanged() {
    val paragraph =
      node(
        NodeType.Paragraph,
        text("first"),
        node(NodeType.LineBreak),
        node(NodeType.Strong, text("second")),
        node(NodeType.SoftBreak),
        node(NodeType.Code, text("third\nfourth")),
      )
    assertEquals("first\\\n**second**\n`third\nfourth`", MarkdownASTSerializer.serializeChildren(paragraph))
    val code = MarkdownASTNode(NodeType.CodeBlock, children = listOf(text("first\nsecond")))
    assertEquals("> ```\n> first\n> second\n> ```\n", MarkdownASTSerializer.serializeBlockquote(node(NodeType.Blockquote, code)))
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
