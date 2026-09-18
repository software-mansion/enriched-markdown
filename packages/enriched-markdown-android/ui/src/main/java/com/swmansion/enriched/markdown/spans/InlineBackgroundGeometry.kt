package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.text.style.LeadingMarginSpan

/**
 * Horizontal measurement shared by the inline [android.text.style.LineBackgroundSpan]s
 * ([CodeBackgroundSpan], [HighlightSpan]), which paint a background behind a run of text
 * rather than across the whole line.
 */
internal object InlineBackgroundGeometry {
  /**
   * Returns the x position of [index] relative to the line's left edge, including any
   * leading margin. The measuring StaticLayout is built from a subSequence that keeps
   * all spans, so LeadingMarginSpans (lists, blockquotes) are already applied to
   * getPrimaryHorizontal; adding the margin again on top would shift the background
   * right by the indent. The margin is only added explicitly in the early-return case,
   * where no layout is built.
   */
  fun horizontalOffset(
    text: CharSequence,
    lineStart: Int,
    lineEnd: Int,
    index: Int,
    paint: Paint,
    leadingMargin: Int,
  ): Float {
    if (index <= lineStart) return leadingMargin.toFloat()
    val lineText = text.subSequence(lineStart, lineEnd)
    val textPaint = paint as? TextPaint ?: TextPaint(paint)
    val layout = StaticLayout.Builder.obtain(lineText, 0, lineText.length, textPaint, 10000).build()
    return layout.getPrimaryHorizontal(index - lineStart)
  }

  fun leadingMarginAt(
    text: Spanned,
    lineStart: Int,
  ): Int {
    if (lineStart >= text.length) return 0
    val spans = text.getSpans(lineStart, lineStart + 1, LeadingMarginSpan::class.java)
    var margin = 0
    for (span in spans) {
      margin += span.getLeadingMargin(false)
    }
    return margin
  }
}
