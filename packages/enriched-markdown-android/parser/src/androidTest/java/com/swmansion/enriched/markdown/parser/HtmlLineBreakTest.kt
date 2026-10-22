package com.swmansion.enriched.markdown.parser

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class HtmlLineBreakTest {
  @Test
  fun paragraphEmitsExistingLineBreakNodes() {
    for (tag in listOf("<br>", "<br/>", "<br />", "<BR>", "<Br/>", "<bR />")) {
      val ast = requireNotNull(Parser.shared.parseMarkdown("one${tag}two"))
      val paragraph = ast.assertHasChildType(MarkdownASTNode.NodeType.Paragraph)
      assertEquals(
        tag,
        listOf(MarkdownASTNode.NodeType.Text, MarkdownASTNode.NodeType.LineBreak, MarkdownASTNode.NodeType.Text),
        paragraph.children.map { it.type },
      )
      assertEquals("one", paragraph.children.first().content)
      assertEquals("two", paragraph.children.last().content)
    }
  }

  @Test
  fun tableBreaksStayInsideTheCell() {
    val source = "| Head<br>two | Code |\n| --- | --- |\n| one<br/>two<BR />three | `one<br>two` |"
    val ast = requireNotNull(Parser.shared.parseMarkdown(source))
    assertEquals(3, ast.allOfType(MarkdownASTNode.NodeType.LineBreak).size)
    assertEquals(2, ast.allOfType(MarkdownASTNode.NodeType.TableRow).size)
    val cell = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.TableCell))
    assertEquals(2, cell.allOfType(MarkdownASTNode.NodeType.LineBreak).size)
    assertEquals(
      "one<br>two",
      ast
        .firstOfType(MarkdownASTNode.NodeType.Code)
        ?.children
        ?.first()
        ?.content,
    )
  }

  @Test
  fun literalControlsAndAutolinks() {
    val controls =
      listOf(
        "\\<br>",
        "&lt;br&gt;",
        "`one<br>two`",
        "```html\none<br>two\n```",
        "one<br class=\"x\">two",
        "one<br title=\"<br>\">two",
        "text <!-- <br> -->",
        "one<br >two",
        "one<br  />two",
        "one<br/ >two",
        "one</br>two",
      )
    for (source in controls) {
      val ast = requireNotNull(Parser.shared.parseMarkdown(source))
      assertTrue(source, ast.allOfType(MarkdownASTNode.NodeType.LineBreak).isEmpty())
    }
    assertNotNull(Parser.shared.parseMarkdown("<br@example.org>")?.firstOfType(MarkdownASTNode.NodeType.Link))
    assertNotNull(Parser.shared.parseMarkdown("<https://example.org>")?.firstOfType(MarkdownASTNode.NodeType.Link))
  }
}
