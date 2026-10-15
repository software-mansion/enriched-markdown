@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.CodeBlockLayout
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginBlockSegment
import com.swmansion.enriched.markdown.plugin.PluginSnapshot

sealed interface MarkdownSegment {
  data class Text(
    val nodes: List<MarkdownASTNode>,
  ) : MarkdownSegment

  data class Table(
    val node: MarkdownASTNode,
  ) : MarkdownSegment

  data class CodeBlock(
    val node: MarkdownASTNode,
  ) : MarkdownSegment

  /** A node a plugin claimed as its own block segment. The payload is produced later, at render time. */
  data class Custom(
    val pluginId: String,
    val plugin: PluginBlockSegment<*>,
    val node: MarkdownASTNode,
  ) : MarkdownSegment
}

/** A top-level code block gets a segment of its own only under [CodeBlockLayout.Scrollable]. */
fun splitASTIntoSegments(
  root: MarkdownASTNode,
  plugins: PluginSnapshot,
  codeBlockLayout: CodeBlockLayout = CodeBlockLayout.Wrapping,
): List<MarkdownSegment> {
  val segments = mutableListOf<MarkdownSegment>()
  val currentTextNodes = mutableListOf<MarkdownASTNode>()

  fun flushTextNodes() {
    if (currentTextNodes.isNotEmpty()) {
      segments.add(MarkdownSegment.Text(currentTextNodes.toList()))
      currentTextNodes.clear()
    }
  }

  for (child in root.children) {
    val claim = plugins.blockSegments[child.type]
    when {
      claim != null -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Custom(claim.pluginId, claim.segment, child))
      }

      child.type == MarkdownASTNode.NodeType.Table -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Table(child))
      }

      // A plugin's own code block renderer only runs in a text segment.
      child.type == MarkdownASTNode.NodeType.CodeBlock &&
        codeBlockLayout == CodeBlockLayout.Scrollable &&
        child.type !in plugins.nodeRenderers -> {
        flushTextNodes()
        segments.add(MarkdownSegment.CodeBlock(child))
      }

      else -> {
        currentTextNodes.add(child)
      }
    }
  }
  flushTextNodes()
  return segments
}
