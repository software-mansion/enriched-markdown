package com.swmansion.enriched.markdown.parser

import com.swmansion.enriched.markdown.input.autolink.LinkRegexConfig
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import java.util.regex.Pattern
import java.util.regex.PatternSyntaxException

/** Native regex parity with iOS ENRMTextLinkRecognizer, applied before AST consumers. */
object TextLinkRecognizer {
  fun recognize(
    ast: MarkdownASTNode,
    linkRegex: LinkRegexConfig? = null,
    inlineCodeLinkRegex: LinkRegexConfig? = null,
  ): MarkdownASTNode {
    val textPattern = compile(linkRegex)
    val codePattern = compile(inlineCodeLinkRegex, wholeSpan = true)
    if (textPattern == null && codePattern == null) return ast

    fun link(
      child: MarkdownASTNode,
      url: String,
    ): MarkdownASTNode =
      MarkdownASTNode(
        NodeType.Link,
        attributes = mapOf("url" to url, "recognizedLink" to "true"),
        children = listOf(child),
      )

    fun transform(node: MarkdownASTNode): List<MarkdownASTNode> {
      when (node.type) {
        NodeType.Link, NodeType.CodeBlock, NodeType.Image, NodeType.Video,
        NodeType.LatexMathInline, NodeType.LatexMathDisplay,
        -> {
          return listOf(node)
        }

        NodeType.Code -> {
          // Code renderers concatenate the parser's text children verbatim.
          val content = node.children.joinToString("") { it.content }
          val matcher = codePattern?.matcher(content)
          if (content.isNotEmpty() && matcher != null && matcher.find() && matcher.start() == 0 && matcher.end() == content.length) {
            return listOf(link(node, content))
          }
          return listOf(node)
        }

        NodeType.Text -> {
          val matcher = textPattern?.matcher(node.content) ?: return listOf(node)
          val result = mutableListOf<MarkdownASTNode>()
          var offset = 0
          while (matcher.find()) {
            val start = matcher.start()
            val end = matcher.end()
            if (start == end) continue
            if (start > offset) result.add(node.copy(content = node.content.substring(offset, start)))
            val matched = node.content.substring(start, end)
            result.add(link(node.copy(content = matched), matched))
            offset = end
          }
          if (offset == 0) return listOf(node)
          if (offset < node.content.length) result.add(node.copy(content = node.content.substring(offset)))
          return result
        }

        else -> {
          return listOf(node.copy(children = node.children.flatMap { transform(it) }))
        }
      }
    }

    // Documents are containers, so recognition never changes their root type.
    return ast.copy(children = ast.children.flatMap { transform(it) })
  }

  private fun compile(
    config: LinkRegexConfig?,
    wholeSpan: Boolean = false,
  ): Pattern? {
    if (config == null || config.isDisabled || config.isDefault || config.pattern.isEmpty()) return null
    var flags = 0
    if (config.caseInsensitive) flags = flags or Pattern.CASE_INSENSITIVE
    if (config.dotAll) flags = flags or Pattern.DOTALL
    return try {
      Pattern.compile(if (wholeSpan) "\\A(?:${config.pattern})\\z" else config.pattern, flags)
    } catch (_: PatternSyntaxException) {
      null
    }
  }
}
