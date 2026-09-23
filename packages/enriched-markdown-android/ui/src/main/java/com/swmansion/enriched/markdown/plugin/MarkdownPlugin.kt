package com.swmansion.enriched.markdown.plugin

import android.content.Context
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.NodeRenderer
import com.swmansion.enriched.markdown.renderer.RendererConfig

@InternalPluginApi
interface MarkdownPlugin {
  /** Stable across releases: it identifies the plugin's registrations and its rendered segments. */
  val id: String

  fun install(registry: PluginRegistry)
}

@InternalPluginApi
interface PluginRegistry {
  /**
   * Claim a node type outright; the plugin renders it into the spannable instead of core.
   *
   * The factory runs once per [com.swmansion.enriched.markdown.renderer.RendererFactory], not per
   * node, so a renderer may cache whatever its config and context allow.
   */
  fun registerNodeRenderer(
    type: MarkdownASTNode.NodeType,
    factory: (RendererConfig, Context) -> NodeRenderer,
  )

  /** Claim a node type as its own block segment with its own View. */
  fun registerBlockSegment(
    type: MarkdownASTNode.NodeType,
    segment: BlockSegmentPlugin,
  )
}
