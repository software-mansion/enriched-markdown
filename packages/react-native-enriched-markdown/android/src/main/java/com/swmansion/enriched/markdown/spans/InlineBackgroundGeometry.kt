package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.style.LeadingMarginSpan

internal object InlineBackgroundGeometry {
  /**
   * Returns the x position of [index] relative to the line's left edge. The measuring layout keeps
   * the line's spans, so a LeadingMarginSpan is already folded into getPrimaryHorizontal — only the
   * early return, which builds no layout, adds [leadingMargin] itself.
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

  /**
   * Visual left/right of [from]..[to] when the line belongs to an RTL paragraph, else null.
   * [horizontalOffset] measures from an LTR layout, which puts RTL lines off to the right; the
   * selection path also handles an LTR run (inline code) embedded in RTL text.
   */
  fun rtlRunBounds(
    text: CharSequence,
    lineStart: Int,
    lineEnd: Int,
    from: Int,
    to: Int,
    paint: Paint,
    lineWidth: Int,
  ): Pair<Float, Float>? {
    // Same rule StaticLayout applies to the whole paragraph (TextView's default first-strong).
    val paragraphStart = text.lastIndexOf('\n', lineStart - 1) + 1
    val paragraphEnd = text.indexOf('\n', lineStart).let { if (it < 0) text.length else it }
    if (!TextDirectionHeuristics.FIRSTSTRONG_LTR.isRtl(text, paragraphStart, paragraphEnd - paragraphStart)) return null
    val lineText = text.subSequence(lineStart, lineEnd)
    val textPaint = paint as? TextPaint ?: TextPaint(paint)
    val layout =
      StaticLayout.Builder
        .obtain(lineText, 0, lineText.length, textPaint, lineWidth.coerceAtLeast(1))
        .setTextDirection(TextDirectionHeuristics.RTL)
        .build()
    val bounds = RectF()
    Path().apply { layout.getSelectionPath(from - lineStart, to - lineStart, this) }.computeBounds(bounds, true)
    return bounds.left to bounds.right
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
