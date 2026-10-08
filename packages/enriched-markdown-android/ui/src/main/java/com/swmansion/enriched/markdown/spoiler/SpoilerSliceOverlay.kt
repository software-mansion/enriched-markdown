package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import kotlin.math.roundToInt

/**
 * Draws the effect over one [SpoilerSlice] of a concealed spoiler; return instances from
 * [CustomSpoilerOverlay.createSliceOverlay]. The canvas is moved to the slice's top-left corner and
 * clipped to its size, and the text under it is already transparent, so no backdrop is needed.
 * All calls come on the main thread.
 */
abstract class SpoilerSliceOverlay {
  /** Draws the concealed slice. [slice] describes it as of this frame. */
  abstract fun draw(
    canvas: Canvas,
    slice: SpoilerSlice,
  )

  /**
   * Draws the slice as it is revealed, with [progress] rising from 0 to 1 over
   * [CustomSpoilerOverlay.revealDurationMillis]. A spoiler's slices reveal together; stagger by
   * [SpoilerSlice.index] to go one after another. The default fades [draw] out; `super` keeps it.
   */
  open fun drawReveal(
    canvas: Canvas,
    slice: SpoilerSlice,
    progress: Float,
  ) {
    val alpha = (overlayAlphaAt(progress) * 255f).roundToInt()
    if (alpha <= 0) return
    val saveCount = canvas.saveLayerAlpha(0f, 0f, slice.width, slice.height, alpha)
    draw(canvas, slice)
    canvas.restoreToCount(saveCount)
  }

  /**
   * Whether the overlay moves on its own, so the view draws every frame; read
   * [SpoilerSlice.frameTimeMillis] to advance the animation.
   */
  open val isAnimated: Boolean get() = false

  /**
   * The slice left the layout, was revealed, or its content, overlay or style changed: release
   * resources.
   */
  open fun onRemoved() {}
}
