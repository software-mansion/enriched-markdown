package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.widget.HorizontalScrollView
import com.swmansion.enriched.markdown.utils.common.findEnrichedMarkdownAncestor

/**
 * Enables its scrollbar only once laid out with content wider than itself: a scrollbar enabled at
 * attach fades out 1.2 s later and redraws every frame for 250 ms, even when nothing scrolls.
 */
internal class OverflowScrollView(
  context: Context,
  // Off for an owner that tells it when its content overflows ([setOverflows]).
  private val detectsOverflow: Boolean = true,
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
    if (detectsOverflow) setOverflows(canScrollHorizontally(1) || canScrollHorizontally(-1))
  }

  /**
   * Shows the scrollbar briefly once content starts to overflow, as a hint. A stream appends blocks:
   * their hints wait for its end ([hintOverflow]).
   */
  fun setOverflows(overflows: Boolean) {
    if (overflows == isHorizontalScrollBarEnabled) return
    isHorizontalScrollBarEnabled = overflows
    if (overflows && findEnrichedMarkdownAncestor()?.streaming != true) awakenScrollBars()
  }

  fun hintOverflow() {
    if (isHorizontalScrollBarEnabled) awakenScrollBars()
  }
}
