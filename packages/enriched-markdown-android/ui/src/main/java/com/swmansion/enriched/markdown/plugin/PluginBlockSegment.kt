package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * A block segment owned by a plugin. [renderPayload] runs on the render thread and must not
 * touch views; create/update/matches run on the main thread.
 */
@InternalPluginApi
interface PluginBlockSegment<P : PluginSegmentPayload> {
  /**
   * Render-thread, so do expensive work here rather than in [updateView]. Returns null to fall back
   * to core text rendering for this node.
   *
   * Report problems with the content to [onPluginEvent] here rather than from the view: core
   * reuses a view whose segment is unchanged without updating it, so a report made from the view
   * would not be repeated once the document is replaced.
   */
  fun renderPayload(
    node: MarkdownASTNode,
    style: StyleConfig,
    context: Context,
    onPluginEvent: PluginEventSink?,
  ): P?

  /** Main thread. */
  fun createView(
    payload: P,
    config: SegmentViewConfig,
  ): View

  fun updateView(
    view: View,
    payload: P,
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
