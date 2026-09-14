package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.parser.MarkdownASTNode

sealed interface MarkdownSegment {
  data class Text(
    val nodes: List<MarkdownASTNode>,
  ) : MarkdownSegment

  data class Math(
    val latex: String,
    val node: MarkdownASTNode,
  ) : MarkdownSegment
}

fun splitASTIntoSegments(root: MarkdownASTNode): List<MarkdownSegment> {
  val segments = mutableListOf<MarkdownSegment>()
  val currentTextNodes = mutableListOf<MarkdownASTNode>()

  fun flushTextNodes() {
    if (currentTextNodes.isNotEmpty()) {
      segments.add(MarkdownSegment.Text(currentTextNodes.toList()))
      currentTextNodes.clear()
    }
  }

  for (child in root.children) {
    when (child.type) {
      MarkdownASTNode.NodeType.LatexMathDisplay -> {
        flushTextNodes()
        val latex =
          if (child.children.isNotEmpty()) {
            child.children.first().content
          } else {
            child.content
          }
        segments.add(MarkdownSegment.Math(latex, child))
      }

      else -> {
        currentTextNodes.add(child)
      }
    }
  }
  flushTextNodes()
  return segments
}
