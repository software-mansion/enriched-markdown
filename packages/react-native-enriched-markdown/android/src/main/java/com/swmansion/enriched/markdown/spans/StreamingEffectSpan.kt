package com.swmansion.enriched.markdown.spans

import android.os.Build
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle

/**
 * Moves the characters' own color [tintAmount] of the way to [tint], then multiplies their
 * opacity by [opacity]. Applied after the spans that set the characters' own colors.
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

  /** How much of the characters shows: 1 as they are, 0 not at all. */
  internal val visibility = (1 + ((tint ushr 24) / 255f - 1) * tintAmount) * opacity

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

/**
 * How much of [text] from [start] to [end] shows, on average: 1 unless a streaming effect animates
 * it. For what is drawn behind or beside the characters, like inline code's background.
 */
internal fun streamingVisibility(
  text: CharSequence?,
  start: Int,
  end: Int,
): Float {
  if (text !is Spanned || end <= start) return 1f
  val effects = text.getSpans(start, end, StreamingEffectSpan::class.java)
  if (effects.isEmpty()) return 1f
  var hidden = 0f
  for (effect in effects) {
    val overlap = minOf(end, text.getSpanEnd(effect)) - maxOf(start, text.getSpanStart(effect))
    if (overlap > 0) hidden += overlap * (1 - effect.visibility)
  }
  return (1 - hidden / (end - start)).coerceIn(0f, 1f)
}
