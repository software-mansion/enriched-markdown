package com.swmansion.enriched.markdown

import android.graphics.Color
import android.text.Spannable
import android.text.SpannableString
import android.text.TextPaint
import com.swmansion.enriched.markdown.spans.StreamingEffectSpan
import com.swmansion.enriched.markdown.spans.streamingVisibility
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

  @Test
  fun visibilityCombinesOpacityAndATranslucentTint() {
    assertEquals(0.5f, StreamingEffectSpan(Color.BLUE, tintAmount = 0f, opacity = 0.5f).visibility, 0.001f)
    // Half way to a transparent tint, at full opacity.
    assertEquals(0.5f, StreamingEffectSpan(Color.TRANSPARENT, tintAmount = 0.5f, opacity = 1f).visibility, 0.001f)
  }

  @Test
  fun textWithoutEffectsIsFullyVisible() {
    assertEquals(1f, streamingVisibility(SpannableString("inline code"), 0, 11), 0.001f)
    assertEquals(1f, streamingVisibility("plain", 0, 5), 0.001f)
  }

  @Test
  fun visibilityAveragesTheCharactersInTheRange() {
    val text = SpannableString("abcdefgh")
    // The last four characters at a quarter, the first four untouched.
    text.setSpan(StreamingEffectSpan(Color.BLUE, tintAmount = 0f, opacity = 0.25f), 4, 8, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
    assertEquals(0.625f, streamingVisibility(text, 0, 8), 0.001f)
    assertEquals(0.25f, streamingVisibility(text, 4, 8), 0.001f)
    assertEquals(1f, streamingVisibility(text, 0, 4), 0.001f)
  }
}
