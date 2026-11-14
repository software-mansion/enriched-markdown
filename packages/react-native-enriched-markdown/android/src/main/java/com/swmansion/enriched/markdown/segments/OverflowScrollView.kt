package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.widget.HorizontalScrollView

/**
 * Enables its scrollbar once laid out with content wider than itself. A scrollbar enabled at attach
 * fades out 1.2 s later and redraws every frame for 250 ms, even when nothing scrolls, so each code
 * or math block a stream appended kept the window drawing after the text had settled. An overflowing
 * block shows its scrollbar when scrolled, and when its window becomes visible again, as any scroll
 * view does.
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
