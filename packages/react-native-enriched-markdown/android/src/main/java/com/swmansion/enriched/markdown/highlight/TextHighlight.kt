package com.swmansion.enriched.markdown.highlight

import androidx.annotation.ColorInt
import com.facebook.react.bridge.ReadableArray
import com.facebook.react.uimanager.PixelUtil

/** A range of text painted behind its glyphs. Lengths are in pixels. */
data class TextHighlight(
  val start: Int,
  val end: Int,
  @param:ColorInt val color: Int,
  val borderRadius: Float,
  val padding: Float,
) {
  /** The part inside [blockStart, blockEnd), in the block's own offsets, or null. */
  fun inBlock(
    blockStart: Int,
    blockEnd: Int,
  ): TextHighlight? {
    val from = maxOf(start, blockStart)
    val to = minOf(end, blockEnd)
    if (to <= from) return null
    return copy(start = from - blockStart, end = to - blockStart)
  }
}

/** Reads the `highlights` prop. Colors arrive as signed 32-bit ARGB integers. */
fun parseTextHighlights(value: ReadableArray?): List<TextHighlight> {
  if (value == null) return emptyList()
  val result = ArrayList<TextHighlight>(value.size())
  for (i in 0 until value.size()) {
    val item = value.getMap(i)
    if (item == null) {
      result += TextHighlight(start = 0, end = 0, color = 0, borderRadius = 0f, padding = 0f)
      continue
    }
    val start = item.getInt("start")
    val end = item.getInt("end")
    // An empty range draws nothing but keeps the later entries at their index.
    val valid = start >= 0 && end > start
    result +=
      TextHighlight(
        start = if (valid) start else 0,
        end = if (valid) end else 0,
        color = item.getInt("color"),
        borderRadius = PixelUtil.toPixelFromDIP(item.getDouble("borderRadius")).coerceAtLeast(0f),
        padding = PixelUtil.toPixelFromDIP(item.getDouble("padding")),
      )
  }
  return result
}
