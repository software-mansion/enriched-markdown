package com.swmansion.enriched.markdown.parser

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class NoIndentedCodeBlocksTest {
  @Test
  fun defaultAndOptInPreserveFencedCode() {
    val markdown = "    **spaces**\n\nSeparator.\n\n\t*tab*\n\n```js\nfenced\n```\n\n~~~\ntilde\n~~~"
    val parser = Parser.shared
    assertEquals(4, requireNotNull(parser.parseMarkdown(markdown)).children.count { it.type == MarkdownASTNode.NodeType.CodeBlock })
    for (enabled in listOf(false, true, false)) {
      val ast = requireNotNull(parser.parseMarkdown(markdown, Md4cFlags(noIndentedCodeBlocks = enabled)))
      assertEquals(if (enabled) 2 else 4, ast.children.count { it.type == MarkdownASTNode.NodeType.CodeBlock })
      assertEquals(enabled, ast.firstOfType(MarkdownASTNode.NodeType.Strong) != null)
      assertEquals(enabled, ast.firstOfType(MarkdownASTNode.NodeType.Emphasis) != null)
    }
  }
}
