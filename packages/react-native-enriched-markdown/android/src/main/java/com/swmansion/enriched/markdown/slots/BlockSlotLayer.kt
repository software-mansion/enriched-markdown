package com.swmansion.enriched.markdown.slots

import android.content.Context
import android.view.ViewGroup

/**
 * Holds the GFM host's Fabric children (the slot views) apart from the segment
 * views, so the segment reconciler's child indices stay its own. Fabric sizes
 * and positions the children itself, so layout here is a no-op like
 * ReactViewGroup's.
 */
class BlockSlotLayer(
  context: Context,
) : ViewGroup(context) {
  init {
    // Slot shadows draw past the slot bounds.
    clipChildren = false
  }

  override fun onMeasure(
    widthMeasureSpec: Int,
    heightMeasureSpec: Int,
  ) {
    setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), MeasureSpec.getSize(heightMeasureSpec))
  }

  override fun onLayout(
    changed: Boolean,
    l: Int,
    t: Int,
    r: Int,
    b: Int,
  ) = Unit

  override fun shouldDelayChildPressedState(): Boolean = false
}
