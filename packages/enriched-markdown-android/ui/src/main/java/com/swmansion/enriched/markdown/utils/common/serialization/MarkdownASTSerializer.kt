package com.swmansion.enriched.markdown.utils.common.serialization

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType

/**
 * Turns AST back into markdown source. The standalone package needs this because AST nodes carry no
 * source offsets, so a rendered block cannot be sliced back out of the original document.
 */
object MarkdownASTSerializer {
  /**
   * Rebuilds a table's markdown, used when copying the table out of the view. Built from the AST
   * rather than from the laid-out rows so alignment markers stay correct in RTL, where a
   * right-aligned column resolves to a start-aligned layout.
   *
   * Only the first header row is followed by an alignment separator: a second one would make the
   * output invalid GFM.
   */
  fun serializeTable(node: MarkdownASTNode): String =
    buildString {
      var headerDone = false
      node.children.forEach { section ->
        section.children.filter { it.type == NodeType.TableRow }.forEach { row ->
          append("| ")
          append(row.children.joinToString(" | ") { serializeChildren(it) })
          append(" |\n")

          if (!headerDone && row.children.firstOrNull()?.type == NodeType.TableHeaderCell) {
            append("| ")
            append(row.children.joinToString(" | ") { alignmentMarker(it.getAttribute("align")) })
            append(" |\n")
            headerDone = true
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
