package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Layout
import android.text.Spanned
import android.text.style.LeadingMarginSpan

/**
 * Draws a list marker on a line owned by another block (a code block, a nested
 * sublist) without contributing any margin of its own. [marker] is never
 * attached to the text; it is the item's marker-drawing span.
 *
 * Set with `SPAN_FLAGS_LIST_MARKER_ANCHOR`, so the `x` it receives is past the
 * enclosing blockquotes only, the origin [marker] would draw from on a plain
 * text line.
 */
class ListMarkerAnchorSpan(
  internal val marker: BaseListSpan,
) : LeadingMarginSpan {
  override fun getLeadingMargin(first: Boolean): Int = 0

  override fun drawLeadingMargin(
    c: Canvas,
    p: Paint,
    x: Int,
    dir: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence?,
    start: Int,
    end: Int,
    first: Boolean,
    layout: Layout?,
  ) {
    if (!first) return
    if (text is Spanned && text.getSpanStart(this) != start) return

    marker.drawMarkerAt(c, p, x, dir, top, baseline, bottom, layout, start)
  }
}
