package com.swmansion.enriched.markdown.parser

import com.swmansion.enriched.markdown.input.autolink.LinkRegexConfig
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.utils.common.serialization.MarkdownASTSerializer

/** Exercises the production C++ parser, JNI adapter, and Kotlin parser hook. */
object ParserTextLinkIntegrationTest {
  private val pattern = LinkRegexConfig("item-\\d+", false, false, false, false)

  @JvmStatic
  fun main(args: Array<String>) {
    val tests =
      listOf(
        "real Markdown links, autolinks and fences stay unchanged" to ::excludedMarkdown,
        "real inline code retains its native code AST and needs a whole match" to ::inlineCode,
        "real nested emphasis and multiple text matches preserve rendered text" to ::nestedText,
        "real parsing stays unchanged without patterns or with invalid native patterns" to ::disabled,
        "native parse transforms are fresh for each recognition configuration" to ::configurationChanges,
        "recognized links preserve plain text and copied Markdown serialization" to ::serialization,
        "CommonMark and GFM parser modes share recognition" to ::parserModes,
      )
    tests.forEach { (name, test) ->
      try {
        test()
        println("PASS: $name")
      } catch (failure: Throwable) {
        throw AssertionError("FAIL: $name", failure)
      }
    }
    println("${tests.size} production JNI parser integration tests passed")
  }

  private fun parse(
    markdown: String,
    text: LinkRegexConfig? = null,
    code: LinkRegexConfig? = null,
    isGFM: Boolean = true,
  ): MarkdownASTNode =
    checkNotNull(
      Parser.shared.parseMarkdown(markdown, isGFM = isGFM, linkRegex = text, inlineCodeLinkRegex = code),
    )

  private fun MarkdownASTNode.all(type: NodeType): List<MarkdownASTNode> =
    (if (this.type == type) listOf(this) else emptyList()) + children.flatMap { it.all(type) }

  private fun MarkdownASTNode.originalText(): String = content + children.joinToString("") { it.originalText() }

  private fun assertEquals(
    expected: Any?,
    actual: Any?,
  ) {
    check(expected == actual) { "Expected <$expected>, got <$actual>" }
  }

  private fun excludedMarkdown() {
    val markdown =
      """
      [item-12](https://original.invalid) <https://auto.invalid/item-34> item-56

      ```text
      item-78
      ```
      """.trimIndent()
    val original = parse(markdown)
    val actual = parse(markdown, pattern, pattern)
    assertEquals(
      listOf("https://original.invalid", "https://auto.invalid/item-34", "item-56"),
      actual.all(NodeType.Link).map { it.getAttribute("url") },
    )
    assertEquals(original.all(NodeType.Link), actual.all(NodeType.Link).take(2))
    assertEquals(original.all(NodeType.CodeBlock), actual.all(NodeType.CodeBlock))
    assertEquals(original.originalText(), actual.originalText())
  }

  private fun inlineCode() {
    val markdown = "`item-12` `before item-34` `item-56 after` `item-78 item-90`"
    val original = parse(markdown)
    val actual = parse(markdown, code = pattern)
    assertEquals(listOf("item-12"), actual.all(NodeType.Link).map { it.getAttribute("url") })
    assertEquals(original.all(NodeType.Code), actual.all(NodeType.Code))
    assertEquals(
      NodeType.Code,
      actual
        .all(NodeType.Link)
        .single()
        .children
        .single()
        .type,
    )
    assertEquals(original.originalText(), actual.originalText())
    assertEquals(original, parse(markdown, text = pattern))
  }

  private fun nestedText() {
    val markdown = "🧪 café *item-12* and **item-34**, item-56 終"
    val original = parse(markdown)
    val actual = parse(markdown, pattern)
    assertEquals(listOf("item-12", "item-34", "item-56"), actual.all(NodeType.Link).map { it.getAttribute("url") })
    assertEquals(original.originalText(), actual.originalText())
    assertEquals("🧪 café item-12 and item-34, item-56 終", actual.originalText())
    assertEquals(1, actual.all(NodeType.Emphasis).size)
    assertEquals(1, actual.all(NodeType.Strong).size)
  }

  private fun disabled() {
    val markdown = "item-12 `item-34`"
    val original = parse(markdown)
    assertEquals(emptyList<MarkdownASTNode>(), original.all(NodeType.Link))
    assertEquals(original, parse(markdown, pattern.copy(isDisabled = true), pattern.copy(isDefault = true)))
    assertEquals(original, parse(markdown, pattern.copy(pattern = "["), pattern.copy(pattern = "(")))
  }

  private fun configurationChanges() {
    val markdown = "item-12 `item-34`"
    assertEquals(listOf("item-12"), parse(markdown, text = pattern).all(NodeType.Link).map { it.getAttribute("url") })
    assertEquals(listOf("item-34"), parse(markdown, code = pattern).all(NodeType.Link).map { it.getAttribute("url") })
    assertEquals(emptyList<MarkdownASTNode>(), parse(markdown).all(NodeType.Link))
  }

  private fun serialization() {
    val markdown = "🧪 item-12 and `item-34` *item-56* [item-78](https://original.invalid)"
    val original = parse(markdown)
    val actual = parse(markdown, pattern, pattern)
    assertEquals(MarkdownASTSerializer.plainText(original), MarkdownASTSerializer.plainText(actual))
    assertEquals(MarkdownASTSerializer.serializeNode(original), MarkdownASTSerializer.serializeNode(actual))
    assertEquals(markdown, MarkdownASTSerializer.serializeNode(actual))
    assertEquals(
      "🧪 item-12 and item-34 item-56 item-78",
      MarkdownASTSerializer.plainText(actual),
    )
  }

  private fun parserModes() {
    val markdown = "item-12 *item-34* `item-56`"
    val gfm = parse(markdown, pattern, pattern, isGFM = true)
    val commonmark = parse(markdown, pattern, pattern, isGFM = false)
    assertEquals(gfm, commonmark)
    assertEquals(listOf("item-12", "item-34", "item-56"), commonmark.all(NodeType.Link).map { it.getAttribute("url") })
  }
}
