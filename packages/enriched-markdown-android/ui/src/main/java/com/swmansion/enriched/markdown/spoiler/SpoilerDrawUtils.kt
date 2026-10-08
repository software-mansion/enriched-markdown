package com.swmansion.enriched.markdown.spoiler

import android.graphics.Color
import android.graphics.Paint
import android.text.Layout
import android.text.Spanned
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan

internal fun computeSliceRect(
  layout: Layout,
  line: Int,
  start: Int,
  end: Int,
  fontMetrics: Paint.FontMetrics,
  paddingLeft: Float,
  paddingTop: Float,
): SliceRect? {
  val startHorizontal = layout.getPrimaryHorizontal(start)
  val endHorizontal =
    if (end >= layout.getLineEnd(line)) {
      layout.getLineRight(line)
    } else {
      layout.getPrimaryHorizontal(end)
    }
  val baseline = layout.getLineBaseline(line).toFloat()

  val left = minOf(startHorizontal, endHorizontal) + paddingLeft
  val right = maxOf(startHorizontal, endHorizontal) + paddingLeft
  var top = baseline + fontMetrics.ascent + paddingTop
  var bottom = baseline + fontMetrics.descent + paddingTop

  val imageHeight = (layout.text as? Spanned)?.blockImageHeight(start, end) ?: 0
  if (imageHeight > 0) {
    val lineTop = layout.getLineTop(line) + paddingTop
    top = minOf(top, lineTop)
    bottom = maxOf(bottom, lineTop + imageHeight)
  }
  val width = right - left
  val height = bottom - top
  return if (width > 0 && height > 0) SliceRect(left, top, width, height) else null
}

private fun Spanned.blockImageHeight(
  start: Int,
  end: Int,
): Int =
  getSpans(start, end, ImageSpan::class.java)
    .filterNot { it.isInline }
    .maxOfOrNull { it.drawable.bounds.height() } ?: 0

internal fun colorWithAlpha(
  color: Int,
  alpha: Float,
): Int {
  val alphaComponent = (Color.alpha(color) * alpha).toInt().coerceIn(0, 255)
  return Color.argb(alphaComponent, Color.red(color), Color.green(color), Color.blue(color))
}

/**
 * How much of `[start, end)` shows through the spoilers over it: 0 while concealed, 1 once revealed
 * or when no spoiler covers it. Lets decorations drawn outside the text paint fade with the text.
 *
 * Replacement spans need it too: the platform hands their `draw` a paint without any
 * `CharacterStyle` applied, so the spoiler's transparent paint never reaches them.
 */
@InternalPluginApi
fun Spanned.spoilerTextAlpha(
  start: Int,
  end: Int,
): Float {
  var alpha = 1f
  for (span in getSpans(start, end, SpoilerSpan::class.java)) {
    if (!span.revealed) alpha = minOf(alpha, span.textAlpha)
  }
  return alpha
}
