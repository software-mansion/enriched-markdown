package com.swmansion.enriched.markdown.segments

import android.view.View

/** Per-kind view work seam used by ContainerNodeView to build and reconcile child views from RenderedSegment data. */
interface SegmentViewFactory {
  fun matchesKind(
    view: View,
    segment: RenderedSegment,
  ): Boolean

  fun createView(segment: RenderedSegment): View

  fun updateView(
    view: View,
    segment: RenderedSegment,
  )
}
