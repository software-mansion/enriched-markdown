package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import kotlin.math.roundToInt

/**
 * Draws the effect over one line segment of a concealed spoiler; return instances from
 * [CustomSpoilerOverlay.createSegment]. The canvas is moved to the segment's top-left corner and
 * clipped to its size, and the text under it is already transparent, so no backdrop is needed.
 * All calls come on the main thread.
 */
abstract class SpoilerSegmentOverlay {
  /** Draws the concealed segment. [segment] describes it as of this frame. */
  abstract fun draw(
    canvas: Canvas,
    segment: SpoilerSegment,
  )

  /**
   * Draws the segment as it is revealed, with [progress] rising from 0 to 1 over
   * [CustomSpoilerOverlay.revealDurationMillis]. All segments reveal together; stagger by
   * [SpoilerSegment.index] to go line by line. The default fades [draw] out; `super` keeps it.
   */
  open fun drawReveal(
    canvas: Canvas,
    segment: SpoilerSegment,
    progress: Float,
  ) {
    val alpha = (overlayAlphaAt(progress) * 255f).roundToInt()
    if (alpha <= 0) return
    val saveCount = canvas.saveLayerAlpha(0f, 0f, segment.width, segment.height, alpha)
    draw(canvas, segment)
    canvas.restoreToCount(saveCount)
  }

  /**
   * Whether the overlay moves on its own, so the view draws every frame; read
   * [SpoilerSegment.frameTimeMillis] to advance the animation.
   */
  open val isAnimated: Boolean get() = false

  /** The segment left the layout, was revealed, or the overlay was replaced: release resources. */
  open fun onRemoved() {}
}
