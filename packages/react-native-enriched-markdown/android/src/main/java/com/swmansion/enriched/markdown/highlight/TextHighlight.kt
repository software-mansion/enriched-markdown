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
    val item = value.getMap(i) ?: continue
    val start = item.getInt("start")
    val end = item.getInt("end")
    if (start < 0 || end <= start) continue
    result +=
      TextHighlight(
        start = start,
        end = end,
        color = item.getInt("color"),
        borderRadius = PixelUtil.toPixelFromDIP(item.getDouble("borderRadius")).coerceAtLeast(0f),
        padding = PixelUtil.toPixelFromDIP(item.getDouble("padding")),
      )
  }
  return result
}
