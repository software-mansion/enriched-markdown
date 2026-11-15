package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.widget.HorizontalScrollView

/**
 * Enables its scrollbar only once laid out with content wider than itself: a scrollbar enabled at
 * attach fades out 1.2 s later and redraws every frame for 250 ms, even when nothing scrolls.
 */
internal class OverflowScrollView(
  context: Context,
) : HorizontalScrollView(context) {
  init {
    isHorizontalScrollBarEnabled = false
  }

  override fun onLayout(
    changed: Boolean,
    l: Int,
    t: Int,
    r: Int,
    b: Int,
  ) {
    super.onLayout(changed, l, t, r, b)
    isHorizontalScrollBarEnabled = canScrollHorizontally(1) || canScrollHorizontally(-1)
  }
}
