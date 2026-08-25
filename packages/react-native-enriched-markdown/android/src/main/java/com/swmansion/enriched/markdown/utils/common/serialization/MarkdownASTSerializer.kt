package com.swmansion.enriched.markdown.utils.common.serialization

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType

object MarkdownASTSerializer {
  fun serializeNode(node: MarkdownASTNode): String {
    val buffer = StringBuilder()
    appendNode(node, buffer)
    return buffer.toString()
  }

  fun serializeChildren(node: MarkdownASTNode): String {
    val buffer = StringBuilder()
    for (child in node.children) {
      appendNode(child, buffer)
    }
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
        buffer.append("**")
        appendChildren(node, buffer)
        buffer.append("**")
      }

      NodeType.Emphasis -> {
        buffer.append("*")
        appendChildren(node, buffer)
        buffer.append("*")
      }

      NodeType.Strikethrough -> {
        buffer.append("~~")
        appendChildren(node, buffer)
        buffer.append("~~")
      }

      NodeType.Underline -> {
        buffer.append("__")
        appendChildren(node, buffer)
        buffer.append("__")
      }

      NodeType.Superscript -> {
        buffer.append("^")
        appendChildren(node, buffer)
        buffer.append("^")
      }

      NodeType.Subscript -> {
        buffer.append("~")
        appendChildren(node, buffer)
        buffer.append("~")
      }

      NodeType.Highlight -> {
        buffer.append("==")
        appendChildren(node, buffer)
        buffer.append("==")
      }

      NodeType.Code -> {
        buffer.append("`")
        appendChildren(node, buffer)
        buffer.append("`")
      }

      NodeType.Link -> {
        val url = node.getAttribute("url") ?: ""
        buffer.append("[")
        appendChildren(node, buffer)
        buffer.append("](")
        buffer.append(url)
        buffer.append(")")
      }

      NodeType.Image -> {
        val alt = node.getAttribute("alt") ?: ""
        val url = node.getAttribute("url") ?: ""
        buffer.append("![")
        buffer.append(alt)
        buffer.append("](")
        buffer.append(url)
        buffer.append(")")
      }

      else -> {
        appendChildren(node, buffer)
      }
    }
  }

  private fun appendChildren(
    node: MarkdownASTNode,
    buffer: StringBuilder,
  ) {
    for (child in node.children) {
      appendNode(child, buffer)
    }
  }
}
