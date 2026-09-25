@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi

sealed interface MarkdownSegment {
  data class Text(
    val nodes: List<MarkdownASTNode>,
  ) : MarkdownSegment

  data class Table(
    val node: MarkdownASTNode,
  ) : MarkdownSegment

  /** A node a plugin claimed as its own block segment. The payload is produced later, at render time. */
  data class Custom(
    val pluginId: String,
    val node: MarkdownASTNode,
  ) : MarkdownSegment
}

/**
 * [claimedBlockSegmentTypes] maps a node type to the id of the plugin that owns it. It defaults to
 * the installed plugins, and is a parameter so tests can hand in their own instead of installing
 * into the process-wide registry.
 */
fun splitASTIntoSegments(
  root: MarkdownASTNode,
  claimedBlockSegmentTypes: Map<MarkdownASTNode.NodeType, String> = EnrichedMarkdownPlugins.snapshot.blockSegmentOwners,
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
    val claimedBy = claimedBlockSegmentTypes[child.type]
    when {
      child.type == MarkdownASTNode.NodeType.Table -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Table(child))
      }

      claimedBy != null -> {
        flushTextNodes()
        segments.add(MarkdownSegment.Custom(claimedBy, child))
      }

      else -> {
        currentTextNodes.add(child)
      }
    }
  }
  flushTextNodes()
  return segments
}
