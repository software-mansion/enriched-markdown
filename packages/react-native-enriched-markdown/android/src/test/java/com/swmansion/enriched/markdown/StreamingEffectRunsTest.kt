package com.swmansion.enriched.markdown

import com.swmansion.enriched.markdown.utils.text.StreamingEffectRuns
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class StreamingEffectRunsTest {
  private data class Run(
    val start: Int,
    val end: Int,
    val opacity: Float,
  )

  private val looksAsked = mutableListOf<IntRange>()

  // Each character's opacity from its index, so the runs show which look they took.
  private fun runs(
    text: String,
    range: IntRange,
    opacityAt: (Int) -> Float,
  ): List<Run> {
    val result = mutableListOf<Run>()
    StreamingEffectRuns().split(
      text,
      range,
      { start, count, _, tintAmounts, opacities ->
        looksAsked.add(start until start + count)
        for (i in 0 until count) {
          tintAmounts[i] = 0f
          opacities[i] = opacityAt(start + i)
        }
      },
    ) { start, end, _, _, opacity -> result.add(Run(start, end, opacity)) }
    return result
  }

  @Test
  fun joinsCharactersOfOneLookAndSkipsThoseDrawnAsTheyAre() {
    val opacities = floatArrayOf(1f, 0.25f, 0.25f, 0.5f, 1f, 1f)
    assertEquals(
      listOf(Run(1, 3, 0.25f), Run(3, 4, 0.5f)),
      runs("abcdef", 0 until 6) { opacities[it] },
    )
  }

  @Test
  fun keepsTheRangeInsideTheText() {
    assertEquals(listOf(Run(2, 4, 0f)), runs("abcd", 2 until 10) { 0f })
    assertEquals(emptyList<Run>(), runs("abcd", 4 until 10) { 0f })
  }

  @Test
  fun startsARangeInsideASurrogatePairAtThePair() {
    // "ab😀cd": the emoji takes units 2 and 3.
    val text = "ab\uD83D\uDE00cd"
    val result = runs(text, 3 until 6) { it / 10f }
    assertEquals(listOf(2 until 6), looksAsked)
    assertEquals(listOf(Run(2, 4, 0.2f), Run(4, 5, 0.4f), Run(5, 6, 0.5f)), result)
  }

  @Test
  fun startsARangeInsideAZwjSequenceAtTheSequence() {
    // "a👩‍💻b": the sequence takes units 1 to 5 (woman, joiner, laptop).
    val text = "a\uD83D\uDC69\u200D\uD83D\uDCBBb"
    val result = runs(text, 4 until 7) { it / 10f }
    assertEquals(listOf(1 until 7), looksAsked)
    // Its units' different looks do not split it: it takes the look of its first unit.
    assertEquals(listOf(Run(1, 6, 0.1f), Run(6, 7, 0.6f)), result)
  }
}
