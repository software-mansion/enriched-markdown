package com.swmansion.enriched.markdown.slots

import android.graphics.Rect
import android.view.View

// Keep in step with ENRMBlockSlotReveal (iOS).

/** The tail fade's ease. */
fun blockSlotRevealEaseOut(progress: Float): Float = 1f - (1f - progress) * (1f - progress)

/** Moves the view up by [offset] px and clips it to [clipHeight] px, with [overhang] px for shadows at the sides and top. */
fun View.applyBlockSlotReveal(
  offset: Int,
  clipHeight: Int?,
  overhang: Int,
) {
  translationY = (-offset).toFloat()
  clipBounds = clipHeight?.let { Rect(-overhang, -overhang, width + overhang, it) }
}
