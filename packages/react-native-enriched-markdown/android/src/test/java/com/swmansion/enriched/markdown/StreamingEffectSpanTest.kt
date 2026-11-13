package com.swmansion.enriched.markdown

import android.graphics.Color
import android.text.TextPaint
import com.swmansion.enriched.markdown.spans.StreamingEffectSpan
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [33])
class StreamingEffectSpanTest {
  private fun paint(
    color: Int,
    underlineColor: Int = 0,
  ) = TextPaint().also {
    it.color = color
    it.underlineColor = underlineColor
  }

  @Test
  fun tintsTheColorAndMultipliesItsOpacity() {
    val tp = paint(Color.BLACK)
    StreamingEffectSpan(Color.BLUE, tintAmount = 1f, opacity = 0.5f).updateDrawState(tp)
    assertEquals(Color.BLUE, tp.color or (0xFF shl 24))
    assertEquals(127, Color.alpha(tp.color))
  }

  @Test
  fun keepsHiddenTextHidden() {
    val tp = paint(Color.TRANSPARENT)
    StreamingEffectSpan(Color.BLUE, tintAmount = 1f, opacity = 1f).updateDrawState(tp)
    assertEquals(0, Color.alpha(tp.color))
  }

  @Test
  fun leavesAnUnsetUnderlineColorToTheTextColor() {
    val tp = paint(Color.BLACK)
    StreamingEffectSpan(Color.BLUE, tintAmount = 1f, opacity = 0.5f).updateDrawState(tp)
    assertEquals(0, tp.underlineColor)
  }

  @Test
  fun tintsASetUnderlineColor() {
    val tp = paint(Color.BLACK, underlineColor = Color.RED)
    StreamingEffectSpan(Color.BLUE, tintAmount = 1f, opacity = 1f).updateDrawState(tp)
    assertEquals(Color.BLUE, tp.underlineColor)
  }
}
