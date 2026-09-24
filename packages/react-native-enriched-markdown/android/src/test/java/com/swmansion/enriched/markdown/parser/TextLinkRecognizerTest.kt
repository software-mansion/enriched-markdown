package com.swmansion.enriched.markdown.parser

import com.swmansion.enriched.markdown.input.autolink.LinkRegexConfig
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType

/** Pure JVM tests. Run scripts/test-text-link-recognizer.sh without an Android SDK. */
object TextLinkRecognizerTest {
  @JvmStatic
  fun main(args: Array<String>) {
    val tests =
      listOf(
        "default and disabled patterns leave the document unchanged" to ::disabledPatterns,
        "multiple matches retain text and matched URL bytes" to ::multipleMatches,
        "recognition retains text node metadata" to ::textMetadata,
        "Unicode and UTF-16 offsets preserve original text" to ::unicodeText,
        "nested emphasis retains structure" to ::nestedEmphasis,
        "Markdown links and autolinks keep their existing URL" to ::existingLinks,
        "code fences and media or math nodes are excluded" to ::excludedNodes,
        "plain text patterns do not recognize inline code" to ::plainPatternSkipsCode,
        "whole inline code becomes a link retaining the code node" to ::wholeInlineCode,
        "whole inline code patterns backtrack across alternatives" to ::inlineCodeAlternatives,
        "partial inline code matches are excluded" to ::partialInlineCode,
        "inline code recognition does not affect plain text" to ::codePatternSkipsText,
        "empty matches are ignored without losing text" to ::emptyMatches,
        "invalid native patterns are ignored independently" to ::invalidPatterns,
        "supported input flags retain their native semantics" to ::supportedFlags,
        "recognizing an already recognized document is idempotent" to ::idempotent,
      )
    tests.forEach { (name, test) ->
      try {
        test()
        println("PASS: $name")
      } catch (failure: Throwable) {
        throw AssertionError("FAIL: $name", failure)
      }
    }
    println("${tests.size} native text link recognition tests passed")
  }

  private fun regex(
    pattern: String,
    caseInsensitive: Boolean = false,
    dotAll: Boolean = false,
    disabled: Boolean = false,
    default: Boolean = false,
  ) = LinkRegexConfig(pattern, caseInsensitive, dotAll, disabled, default)

  private fun text(content: String) = MarkdownASTNode(NodeType.Text, content = content)

  private fun node(
    type: NodeType,
    vararg children: MarkdownASTNode,
  ) = MarkdownASTNode(type, children = children.toList())

  private fun document(vararg children: MarkdownASTNode) = node(NodeType.Document, node(NodeType.Paragraph, *children))

  private fun link(
    url: String,
    vararg children: MarkdownASTNode,
    recognized: Boolean = true,
  ) = MarkdownASTNode(
    NodeType.Link,
    attributes = if (recognized) mapOf("url" to url, "recognizedLink" to "true") else mapOf("url" to url),
    children = children.toList(),
  )

  private fun MarkdownASTNode.links(): List<MarkdownASTNode> =
    (if (type == NodeType.Link) listOf(this) else emptyList()) + children.flatMap { it.links() }

  private fun MarkdownASTNode.originalText(): String = content + children.joinToString("") { it.originalText() }

  private fun assertEquals(
    expected: Any?,
    actual: Any?,
  ) {
    check(expected == actual) { "Expected <$expected>, got <$actual>" }
  }

  private fun disabledPatterns() {
    val ast = document(text("item-12"), node(NodeType.Code, text("item-34")))
    assertEquals(ast, TextLinkRecognizer.recognize(ast))
    listOf(regex("item-\\d+", disabled = true), regex("item-\\d+", default = true), regex("")).forEach {
      assertEquals(ast, TextLinkRecognizer.recognize(ast, it, it))
    }
  }

  private fun multipleMatches() {
    val original = "Before item-12, item-34 after."
    val actual = TextLinkRecognizer.recognize(document(text(original)), regex("item-\\d+"))
    assertEquals(
      document(text("Before "), link("item-12", text("item-12")), text(", "), link("item-34", text("item-34")), text(" after.")),
      actual,
    )
    assertEquals(original, actual.originalText())
  }

  private fun textMetadata() {
    val original = text("a item-12 b").copy(attributes = mapOf("source" to "original"))
    val actual = TextLinkRecognizer.recognize(document(original), regex("item-\\d+"))
    val leaves =
      actual.children
        .single()
        .children
        .flatMap { if (it.type == NodeType.Link) it.children else listOf(it) }
    check(leaves.all { it.attributes == original.attributes })
    assertEquals(original.content, actual.originalText())
  }

  private fun unicodeText() {
    val original = "🧪 café item-12 👩🏽‍💻 item-34 終"
    val actual = TextLinkRecognizer.recognize(document(text(original)), regex("item-\\d+"))
    assertEquals(listOf("item-12", "item-34"), actual.links().map { it.getAttribute("url") })
    assertEquals(original, actual.originalText())
  }

  private fun nestedEmphasis() {
    val ast = document(node(NodeType.Emphasis, text("See item-12")), node(NodeType.Strong, text("item-34")))
    val actual = TextLinkRecognizer.recognize(ast, regex("item-\\d+"))
    assertEquals(
      listOf(NodeType.Emphasis, NodeType.Strong),
      actual.children
        .single()
        .children
        .map { it.type },
    )
    assertEquals(listOf("item-12", "item-34"), actual.links().map { it.getAttribute("url") })
    assertEquals(ast.originalText(), actual.originalText())
  }

  private fun existingLinks() {
    val explicit = link("https://original.invalid", text("item-12"), node(NodeType.Code, text("item-34")), recognized = false)
    val autolink = link("https://autolink.invalid/item-56", text("https://autolink.invalid/item-56"), recognized = false)
    val ast = document(explicit, text(" item-78 "), autolink)
    val actual = TextLinkRecognizer.recognize(ast, regex("item-\\d+"), regex("item-\\d+"))
    assertEquals(listOf(explicit, link("item-78", text("item-78")), autolink), actual.links())
    assertEquals(ast.originalText(), actual.originalText())
  }

  private fun excludedNodes() {
    val excluded =
      listOf(NodeType.CodeBlock, NodeType.Image, NodeType.Video, NodeType.LatexMathInline, NodeType.LatexMathDisplay)
        .map { node(it, text("item-12"), node(NodeType.Code, text("item-34"))) }
    val ast = MarkdownASTNode(NodeType.Document, children = excluded)
    assertEquals(ast, TextLinkRecognizer.recognize(ast, regex("item-\\d+"), regex("item-\\d+")))
  }

  private fun plainPatternSkipsCode() {
    val code = node(NodeType.Code, text("item-12"))
    assertEquals(document(code), TextLinkRecognizer.recognize(document(code), regex("item-\\d+")))
  }

  private fun wholeInlineCode() {
    val code = node(NodeType.Code, text("item-"), text("12")).copy(attributes = mapOf("source" to "original"))
    val ast = document(text("Before "), code, text(" after"))
    val actual = TextLinkRecognizer.recognize(ast, inlineCodeLinkRegex = regex("item-\\d+"))
    assertEquals(document(text("Before "), link("item-12", code), text(" after")), actual)
    assertEquals(ast.originalText(), actual.originalText())
    check(
      actual
        .links()
        .single()
        .children
        .single() === code,
    ) { "The link must retain the original code node" }
  }

  private fun partialInlineCode() {
    listOf("before item-12", "item-12 after", "item-12 item-34", "").forEach { content ->
      val ast = document(node(NodeType.Code, text(content)))
      assertEquals(ast, TextLinkRecognizer.recognize(ast, inlineCodeLinkRegex = regex("item-\\d+")))
    }
  }

  private fun inlineCodeAlternatives() {
    val code = node(NodeType.Code, text("ab"))
    assertEquals(document(link("ab", code)), TextLinkRecognizer.recognize(document(code), inlineCodeLinkRegex = regex("a|ab")))
  }

  private fun codePatternSkipsText() {
    val ast = document(text("item-12"))
    assertEquals(ast, TextLinkRecognizer.recognize(ast, inlineCodeLinkRegex = regex("item-\\d+")))
  }

  private fun emptyMatches() {
    val ast = document(text("abc xx def"))
    val actual = TextLinkRecognizer.recognize(ast, regex("x*"))
    assertEquals(listOf("xx"), actual.links().map { it.getAttribute("url") })
    assertEquals(ast.originalText(), actual.originalText())
    assertEquals(ast, TextLinkRecognizer.recognize(ast, regex("(?=x)")))
    val code = document(node(NodeType.Code, text("")))
    assertEquals(code, TextLinkRecognizer.recognize(code, inlineCodeLinkRegex = regex("x*")))
  }

  private fun invalidPatterns() {
    val ast = document(text("item-12"), node(NodeType.Code, text("item-34")))
    assertEquals(ast, TextLinkRecognizer.recognize(ast, regex("["), regex("(")))
    val plainInvalid = TextLinkRecognizer.recognize(ast, regex("["), regex("item-\\d+"))
    assertEquals(listOf("item-34"), plainInvalid.links().map { it.getAttribute("url") })
    val codeInvalid = TextLinkRecognizer.recognize(ast, regex("item-\\d+"), regex("("))
    assertEquals(listOf("item-12"), codeInvalid.links().map { it.getAttribute("url") })
  }

  private fun supportedFlags() {
    val ast = document(text("ITEM-12\nitem-34"))
    val insensitive = TextLinkRecognizer.recognize(ast, regex("item-\\d+", caseInsensitive = true))
    assertEquals(listOf("ITEM-12", "item-34"), insensitive.links().map { it.getAttribute("url") })
    val code = node(NodeType.Code, text("first\nlast"))
    assertEquals(document(code), TextLinkRecognizer.recognize(document(code), inlineCodeLinkRegex = regex("first.last")))
    val dotAll = TextLinkRecognizer.recognize(document(code), inlineCodeLinkRegex = regex("first.last", dotAll = true))
    assertEquals(document(link("first\nlast", code)), dotAll)
  }

  private fun idempotent() {
    val ast = document(text("item-12"), node(NodeType.Code, text("item-34")))
    val pattern = regex("item-\\d+")
    val actual = TextLinkRecognizer.recognize(ast, pattern, pattern)
    assertEquals(actual, TextLinkRecognizer.recognize(actual, pattern, pattern))
  }
}
