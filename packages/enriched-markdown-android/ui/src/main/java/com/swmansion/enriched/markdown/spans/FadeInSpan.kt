package com.swmansion.enriched.markdown.spans

import android.text.TextPaint
import android.text.style.CharacterStyle
import androidx.annotation.FloatRange

class FadeInSpan : CharacterStyle() {
  @set:FloatRange(from = 0.0, to = 1.0)
  var alpha: Float = 0f

  override fun updateDrawState(tp: TextPaint) {
    tp.color = multiplyAlpha(tp.color, alpha)
    tp.underlineColor = multiplyAlpha(tp.underlineColor, alpha)
  }

  private fun multiplyAlpha(
    color: Int,
    alpha: Float,
  ): Int {
    if (alpha >= 1f) return color
    if (alpha <= 0f) return color and 0x00FFFFFF
    val a = ((color ushr 24) * alpha).toInt()
    return (a shl 24) or (color and 0x00FFFFFF)
  }
}
