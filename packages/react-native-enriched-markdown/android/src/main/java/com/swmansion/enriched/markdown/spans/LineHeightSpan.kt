package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import kotlin.math.ceil
import kotlin.math.floor
import android.text.style.LineHeightSpan as AndroidLineHeightSpan

class LineHeightSpan(
  height: Float,
) : AndroidLineHeightSpan {
  private val lineHeight: Int = ceil(height.toDouble()).toInt()

  override fun chooseHeight(
    text: CharSequence?,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt?,
  ) {
    if (fm == null) return

    val leading = lineHeight - ((-fm.ascent) + fm.descent)
    // When the line's natural content is already at least as tall as lineHeight
    // (leading <= 0), shrinking ascent/descent to force the smaller lineHeight
    // clips tall glyphs (e.g. stacked combining marks) and drags the whole line
    // up (issue #643). Keep the natural metrics in that case so the line grows
    // to fit its content instead of clipping. Only positive leading is
    // distributed, so normally-sized lines are unaffected.
    if (leading <= 0) return
    fm.ascent -= ceil(leading / 2.0f).toInt()
    fm.descent += floor(leading / 2.0f).toInt()
  }
}
