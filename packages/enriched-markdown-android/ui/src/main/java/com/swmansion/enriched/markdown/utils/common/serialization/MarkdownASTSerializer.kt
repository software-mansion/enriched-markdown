package com.swmansion.enriched.markdown.utils.common.serialization

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType

/** Turns AST back into markdown source; AST nodes carry no source offsets to slice from. */
object MarkdownASTSerializer {
  /**
   * Rebuilds a table's markdown for "Copy as Markdown". Built from the AST rather than from the
   * laid-out rows so alignment markers stay correct in RTL, where a right-aligned column resolves
   * to a start-aligned layout.
   */
  fun serializeTable(node: MarkdownASTNode): String =
    buildString {
      node.children.forEach { section ->
        section.children.filter { it.type == NodeType.TableRow }.forEach { row ->
          append("| ")
          // A literal pipe would otherwise start a new column.
          append(row.children.joinToString(" | ") { serializeChildren(it).replace("|", "\\|") })
          append(" |\n")

          // md4c always emits exactly one head row (guarded by ParserTest).
          if (section.type == NodeType.TableHead) {
            append("| ")
            append(row.children.joinToString(" | ") { alignmentMarker(it.getAttribute("align")) })
            append(" |\n")
          }
        }
      }
    }

  private fun alignmentMarker(align: String?): String =
    when (align) {
      "center" -> ":---:"
      "right" -> "---:"
      "left" -> ":---"
      else -> "---"
    }

  fun serializeChildren(node: MarkdownASTNode): String {
    val buffer = StringBuilder()
    node.children.forEach { appendNode(it, buffer) }
    return buffer.toString()
  }

  private fun appendNode(
    node: MarkdownASTNode,
    buffer: StringBuilder,
  ) {
    when (node.type) {
      NodeType.Text -> {
        buffer.append(node.content)
      }

      NodeType.LineBreak -> {
        buffer.append("\\\n")
      }

      NodeType.SoftBreak -> {
        buffer.append("\n")
      }

      NodeType.Strong -> {
        buffer.wrap("**", node)
      }

      NodeType.Emphasis -> {
        buffer.wrap("*", node)
      }

      NodeType.Strikethrough -> {
        buffer.wrap("~~", node)
      }

      NodeType.Underline -> {
        buffer.wrap("__", node)
      }

      NodeType.Superscript -> {
        buffer.wrap("^", node)
      }

      NodeType.Subscript -> {
        buffer.wrap("~", node)
      }

      NodeType.Highlight -> {
        buffer.wrap("==", node)
      }

      NodeType.Code -> {
        buffer.wrap("`", node)
      }

      NodeType.Link -> {
        buffer.append("[")
        appendChildren(node, buffer)
        buffer.append("](").append(node.getAttribute("url").orEmpty()).append(")")
      }

      NodeType.Image -> {
        buffer.append("![")
        appendChildren(node, buffer)
        buffer.append("](").append(node.getAttribute("url").orEmpty()).append(")")
      }

      else -> {
        appendChildren(node, buffer)
      }
    }
  }

  private fun StringBuilder.wrap(
    delimiter: String,
    node: MarkdownASTNode,
  ) {
    append(delimiter)
    appendChildren(node, this)
    append(delimiter)
  }

  private fun appendChildren(
    node: MarkdownASTNode,
    buffer: StringBuilder,
  ) {
    node.children.forEach { appendNode(it, buffer) }
  }
}
