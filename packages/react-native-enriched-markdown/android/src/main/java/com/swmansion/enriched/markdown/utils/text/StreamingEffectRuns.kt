package com.swmansion.enriched.markdown.utils.text

import android.icu.text.BreakIterator

/**
 * Splits a streaming text's animated characters into runs of equal look, one
 * [com.swmansion.enriched.markdown.spans.StreamingEffectSpan] each. Runs start and end only between
 * characters: a span splitting a character (an emoji) breaks its drawing.
 */
class StreamingEffectRuns {
  fun interface Looks {
    /** Fills the looks of [count] characters from [start]: each tint (ARGB), its amount and the opacity. */
    fun fill(
      start: Int,
      count: Int,
      tints: IntArray,
      tintAmounts: FloatArray,
      opacities: FloatArray,
    )
  }

  fun interface Run {
    fun add(
      start: Int,
      end: Int,
      tint: Int,
      tintAmount: Float,
      opacity: Float,
    )
  }

  private val characters = BreakIterator.getCharacterInstance()
  private var tints = IntArray(0)
  private var tintAmounts = FloatArray(0)
  private var opacities = FloatArray(0)

  /** Calls [run] for each run of the characters of [text] in [range] not drawn as they are. */
  fun split(
    text: CharSequence,
    range: IntRange,
    looks: Looks,
    run: Run,
  ) {
    val end = (range.last + 1).coerceIn(0, text.length)
    var start = range.first.coerceIn(0, end)
    // The range counts UTF-16 units, so it can start inside a character.
    val from = maxOf(0, start - MAX_CHARACTER_LENGTH)
    characters.setText(text.substring(from, end))
    if (start < end && !characters.isBoundary(start - from)) start = from + characters.preceding(start - from)
    val count = end - start
    if (count <= 0) return
    if (tints.size < count) {
      tints = IntArray(count)
      tintAmounts = FloatArray(count)
      opacities = FloatArray(count)
    }
    looks.fill(start, count, tints, tintAmounts, opacities)
    var runStart = 0

    fun looksLikeRun(i: Int) = tints[i] == tints[runStart] && tintAmounts[i] == tintAmounts[runStart] && opacities[i] == opacities[runStart]
    for (i in 1..count) {
      if (i < count && (!characters.isBoundary(start - from + i) || looksLikeRun(i))) continue
      if (tintAmounts[runStart] != 0f || opacities[runStart] != 1f) {
        run.add(start + runStart, start + i, tints[runStart], tintAmounts[runStart], opacities[runStart])
      }
      runStart = i
    }
  }

  private companion object {
    // How far back a character the range starts inside can begin (an emoji ZWJ sequence).
    const val MAX_CHARACTER_LENGTH = 32
  }
}
