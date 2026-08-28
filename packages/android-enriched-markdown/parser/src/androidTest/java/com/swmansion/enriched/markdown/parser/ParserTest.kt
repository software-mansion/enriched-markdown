package com.swmansion.enriched.markdown.parser

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ParserTest {
  private val parser = Parser.shared

  @Test
  fun blankInputReturnsNull() {
    assertNull(parser.parseMarkdown(""))
    assertNull(parser.parseMarkdown("   "))
  }

  @Test
  fun parsesPlainParagraph() {
    val ast = requireNotNull(parser.parseMarkdown("Hello world"))

    assertEquals(MarkdownASTNode.NodeType.Document, ast.type)
    val paragraph = ast.assertHasChildType(MarkdownASTNode.NodeType.Paragraph)
    val text = paragraph.assertHasChildType(MarkdownASTNode.NodeType.Text)
    assertEquals("Hello world", text.content)
  }

  @Test
  fun parsesStrongAndEmphasis() {
    val ast = requireNotNull(parser.parseMarkdown("**bold** and *italic*"))

    val strong = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Strong))
    assertEquals("bold", strong.assertHasChildType(MarkdownASTNode.NodeType.Text).content)

    val emphasis = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Emphasis))
    assertEquals("italic", emphasis.assertHasChildType(MarkdownASTNode.NodeType.Text).content)
  }

  @Test
  fun parsesLinkWithHref() {
    val ast = requireNotNull(parser.parseMarkdown("[React Native](https://reactnative.dev)"))

    val link = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Link))
    assertEquals("React Native", link.assertHasChildType(MarkdownASTNode.NodeType.Text).content)
    assertEquals("https://reactnative.dev", link.getAttribute("url"))
  }

  @Test
  fun parsesHeadingWithLevel() {
    val ast = requireNotNull(parser.parseMarkdown("## Section"))

    val heading = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Heading))
    assertEquals("2", heading.getAttribute("level"))
    assertEquals("Section", heading.assertHasChildType(MarkdownASTNode.NodeType.Text).content)
  }

  @Test
  fun parsesNestedList() {
    val markdown =
      """
      1. first
      2. second
      """.trimIndent()

    val ast = requireNotNull(parser.parseMarkdown(markdown))

    val orderedList = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.OrderedList))
    val listItems = orderedList.allOfType(MarkdownASTNode.NodeType.ListItem)
    assertEquals(2, listItems.size)
    assertTrue(listItems[0].firstOfType(MarkdownASTNode.NodeType.Text)?.content?.contains("first") == true)
    assertTrue(listItems[1].firstOfType(MarkdownASTNode.NodeType.Text)?.content?.contains("second") == true)
  }

  @Test
  fun parsesCodeBlock() {
    val ast = requireNotNull(parser.parseMarkdown("```\nval x = 1\n```"))

    val codeBlock = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.CodeBlock))
    val codeText = requireNotNull(codeBlock.firstOfType(MarkdownASTNode.NodeType.Text))
    assertTrue(codeText.content.contains("val x = 1"))
  }

  @Test
  fun parsesTableStructure() {
    val markdown =
      """
      | H1 | H2 |
      |----|----|
      | a  | b  |
      """.trimIndent()

    val ast = requireNotNull(parser.parseMarkdown(markdown))

    requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Table))
    requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.TableHead))
    requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.TableBody))
    requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.TableRow))
    requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.TableCell))
  }

  @Test
  fun respectsUnderlineFlag() {
    val withUnderline =
      requireNotNull(
        parser.parseMarkdown("__underlined__", Md4cFlags(underline = true)),
      )
    assertNotNull(withUnderline.firstOfType(MarkdownASTNode.NodeType.Underline))

    val withoutUnderline =
      requireNotNull(
        parser.parseMarkdown("__strong__", Md4cFlags(underline = false)),
      )
    assertNotNull(withoutUnderline.firstOfType(MarkdownASTNode.NodeType.Strong))
    assertNull(withoutUnderline.firstOfType(MarkdownASTNode.NodeType.Underline))
  }

  @Test
  fun parsesUnicodeContent() {
    val ast = requireNotNull(parser.parseMarkdown("Cześć 🌍"))

    val text = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Text))
    assertEquals("Cześć 🌍", text.content)
  }

  @Test
  fun nodeTypeEnumCountMatches() {
    assertEquals(30, MarkdownASTNode.NodeType.entries.size)
  }

  @Test
  fun parsesHtmlBreakTagsAsLineBreaks() {
    for (tag in listOf("<br>", "<br/>", "<br />", "<BR>")) {
      val ast = requireNotNull(parser.parseMarkdown("line one${tag}line two"))
      val paragraph = ast.assertHasChildType(MarkdownASTNode.NodeType.Paragraph)

      assertEquals(
        "failed for $tag",
        listOf(
          MarkdownASTNode.NodeType.Text,
          MarkdownASTNode.NodeType.LineBreak,
          MarkdownASTNode.NodeType.Text,
        ),
        paragraph.children.map { it.type },
      )
      assertEquals("line one", paragraph.children.first().content)
      assertEquals("line two", paragraph.children.last().content)
    }
  }

  @Test
  fun preservesOtherInlineHtmlAsText() {
    val markdown = "before<span>inside</span><br class=\"ignored\">after"
    val ast = requireNotNull(parser.parseMarkdown(markdown))
    val paragraph = ast.assertHasChildType(MarkdownASTNode.NodeType.Paragraph)

    assertEquals(listOf(MarkdownASTNode.NodeType.Text), paragraph.children.map { it.type })
    assertEquals(markdown, paragraph.children.first().content)
  }

  @Test
  fun preservesHtmlBreakInsideCodeSpan() {
    val ast = requireNotNull(parser.parseMarkdown("`<br>`"))
    val code = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Code))

    assertEquals(listOf(MarkdownASTNode.NodeType.Text), code.children.map { it.type })
    assertEquals("<br>", code.children.first().content)
  }

  @Test
  fun parsesHtmlBreakInsideTableCell() {
    val ast = requireNotNull(parser.parseMarkdown("| Header |\n| --- |\n| line one<br>line two |"))
    val cell = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.TableCell))

    assertEquals(
      listOf(
        MarkdownASTNode.NodeType.Text,
        MarkdownASTNode.NodeType.LineBreak,
        MarkdownASTNode.NodeType.Text,
      ),
      cell.children.map { it.type },
    )
    assertEquals("line one", cell.children.first().content)
    assertEquals("line two", cell.children.last().content)
  }

  @Test
  fun parsesDeeplyNestedBlockquotes() {
    val depth = 500
    val markdown = "> ".repeat(depth) + "deep"

    val ast = requireNotNull(parser.parseMarkdown(markdown))

    val text = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.Text))
    assertEquals("deep", text.content)
    assertEquals(depth, ast.allOfType(MarkdownASTNode.NodeType.Blockquote).size)
  }

  @Test
  fun parsesWideUnorderedList() {
    val itemCount = 600
    val markdown = (1..itemCount).joinToString("\n") { "- item $it" }

    val ast = requireNotNull(parser.parseMarkdown(markdown))

    val list = requireNotNull(ast.firstOfType(MarkdownASTNode.NodeType.UnorderedList))
    val listItems = list.children.filter { it.type == MarkdownASTNode.NodeType.ListItem }
    assertEquals(itemCount, listItems.size)
    assertEquals(
      "item 1",
      requireNotNull(listItems.first().firstOfType(MarkdownASTNode.NodeType.Text)).content.trim(),
    )
    assertEquals(
      "item $itemCount",
      requireNotNull(listItems.last().firstOfType(MarkdownASTNode.NodeType.Text)).content.trim(),
    )
  }
}
