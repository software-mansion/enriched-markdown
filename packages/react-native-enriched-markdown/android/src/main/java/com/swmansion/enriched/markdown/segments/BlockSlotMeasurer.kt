package com.swmansion.enriched.markdown.segments

/**
 * Measures a slot child during the view-free walk. Origin and width are px,
 * absolute within the host content box; the result is the child's height in px.
 */
fun interface BlockSlotMeasurer {
  fun measure(
    slotId: String,
    xPx: Float,
    yPx: Float,
    widthPx: Float,
  ): Float

  /** Forgets every slot measured so far: the walk failed and falls back to native blocks. */
  fun discard() = Unit
}
