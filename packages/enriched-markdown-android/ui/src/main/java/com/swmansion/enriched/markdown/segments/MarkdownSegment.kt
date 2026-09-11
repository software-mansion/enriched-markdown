package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.parser.MarkdownASTNode

sealed interface MarkdownSegment {
  data class Text(
    val nodes: List<MarkdownASTNode>,
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
    currentTextNodes.add(child)
  }
  flushTextNodes()
  return segments
}
