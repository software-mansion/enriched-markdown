package com.swmansion.enriched.markdown.utils.text.view

import android.view.MotionEvent
import android.widget.TextView

/** Character offset under a touch event, or null when the touch lands outside actual text content. */
internal fun charOffsetAt(
  widget: TextView,
  event: MotionEvent,
): Int? {
  val x = event.x - widget.totalPaddingLeft + widget.scrollX
  val y = event.y - widget.totalPaddingTop + widget.scrollY
  val layout = widget.layout ?: return null

  // getLineForVertical clamps to the first/last line for out-of-range
  // values, so taps in vertical padding would silently map to a real
  // line. Reject them before proceeding.
  if (y < 0f || y > layout.height) {
    return null
  }

  val line = layout.getLineForVertical(y.toInt())

  // getOffsetForHorizontal snaps to the nearest character even when the
  // tap is outside the actual text content (e.g. empty space after the
  // last word on a line). Guard against that by checking the tap falls
  // within the line's text bounds.
  if (x < layout.getLineLeft(line) || x > layout.getLineRight(line)) {
    return null
  }

  return layout.getOffsetForHorizontal(line, x)
}
