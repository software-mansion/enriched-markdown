package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * A block segment owned by a plugin. [renderPayload] runs on the render thread and must not
 * touch views; create/update/matches run on the main thread.
 *
 * A plugin that claims several block node types implements one of these for all of them and
 * switches on `node.type`: views are looked up by plugin id, which cannot tell two
 * implementations of the same plugin apart.
 */
@InternalPluginApi
interface BlockSegmentPlugin {
  /** Render-thread. Returns null to fall back to core text rendering for this node. */
  fun renderPayload(
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
  ): PluginSegmentPayload?

  /** Main thread. */
  fun createView(
    payload: PluginSegmentPayload,
    config: SegmentViewConfig,
  ): View

  fun updateView(
    view: View,
    payload: PluginSegmentPayload,
    config: SegmentViewConfig,
  )

  fun matchesView(view: View): Boolean
}

/**
 * Immutable, thread-confinement-free data handed from the render thread to view creation.
 * Core - not the plugin - computes the segment signature, from [signatureSource].
 */
@InternalPluginApi
interface PluginSegmentPayload {
  /** Stable for identical content; differing content must produce a different string. */
  val signatureSource: String
}
