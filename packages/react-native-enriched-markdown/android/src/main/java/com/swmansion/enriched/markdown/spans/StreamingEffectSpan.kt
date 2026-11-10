package com.swmansion.enriched.markdown.spans

import android.os.Build
import android.text.TextPaint
import android.text.style.CharacterStyle

/**
 * Draws characters with a streaming effect's look: their own color moved [tintAmount] of the way
 * to [tint], then their opacity multiplied by [opacity]. Applied after the spans that set the
 * characters' own colors.
 */
class StreamingEffectSpan(
  private val tint: Int,
  private val tintAmount: Float,
  private val opacity: Float,
) : CharacterStyle() {
  override fun updateDrawState(tp: TextPaint) {
    tp.color = look(tp.color)
    // Public from API 29; below that, and while it is 0, underlines are drawn in `color`.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && tp.underlineColor != 0) {
      tp.underlineColor = look(tp.underlineColor)
    }
  }

  private fun look(own: Int): Int {
    fun channel(shift: Int): Float {
      val from = (own ushr shift) and 0xFF
      val to = (tint ushr shift) and 0xFF
      return from + (to - from) * tintAmount
    }
    // The character's own alpha stays: hidden text stays hidden.
    val tintAlpha = (tint ushr 24) / 255f
    val alpha = ((own ushr 24) * (1 + (tintAlpha - 1) * tintAmount) * opacity).toInt().coerceIn(0, 255)
    return (alpha shl 24) or
      (channel(16).toInt().coerceIn(0, 255) shl 16) or
      (channel(8).toInt().coerceIn(0, 255) shl 8) or
      channel(0).toInt().coerceIn(0, 255)
  }
}
