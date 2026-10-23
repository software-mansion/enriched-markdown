package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.text.Spanned
import kotlin.math.ceil
import kotlin.math.floor
import android.text.style.LineHeightSpan as AndroidLineHeightSpan

class LineHeightSpan(
  height: Float,
) : AndroidLineHeightSpan {
  private val lineHeight: Int = ceil(height.toDouble()).toInt()

  /**
   * Distributes positive leading evenly above and below the line to reach
   * lineHeight.
   *
   * When the line's natural content is already at least as tall as lineHeight
   * (leading <= 0), we keep the natural metrics and return early. Forcing the
   * smaller lineHeight by shrinking ascent/descent clips tall glyphs (e.g.
   * stacked combining marks) and drags the whole line up (issue #643); letting
   * the line grow to fit its content avoids that. Normally-sized lines have
   * positive leading and are unaffected.
   *
   * Spacer lines (a lone "\n" carrying a [MarginBottomSpan]) are left alone:
   * MarginBottomSpan sets them to exactly marginBottom. Both spans edit `fm` in
   * place, so otherwise the result depends on which one runs last, and Android
   * does not call them in the same order for the shadow node's StaticLayout and
   * for the TextView's own layout. Yoga would then size the view from one
   * spacer height while the TextView draws the other.
   */
  override fun chooseHeight(
    text: CharSequence?,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt?,
  ) {
    if (fm == null) return
    if (isSpacerLine(text, start, end)) return

    val leading = lineHeight - ((-fm.ascent) + fm.descent)
    if (leading <= 0) return
    fm.ascent -= ceil(leading / 2.0f).toInt()
    fm.descent += floor(leading / 2.0f).toInt()
  }

  private fun isSpacerLine(
    text: CharSequence?,
    start: Int,
    end: Int,
  ): Boolean =
    text is Spanned &&
      end - start == 1 &&
      text[start] == '\n' &&
      text.getSpans(start, end, MarginBottomSpan::class.java).isNotEmpty()
}
