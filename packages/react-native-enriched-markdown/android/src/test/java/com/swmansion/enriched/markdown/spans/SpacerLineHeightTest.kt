package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.text.SpannableStringBuilder
import android.text.Spanned
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import android.text.style.LineHeightSpan as AndroidLineHeightSpan

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SpacerLineHeightTest {
  private val lineHeight = LineHeightSpan(LINE_HEIGHT)
  private val marginBottom = MarginBottomSpan(MARGIN_BOTTOM)
  private val text =
    SpannableStringBuilder("Paragraph\n\nNext").apply {
      setSpan(lineHeight, 0, length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      setSpan(marginBottom, SPACER, SPACER + 1, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    }

  // Android does not call a line's height spans in a fixed order: the shadow
  // node's StaticLayout and the TextView's own layout can disagree. Run both
  // spans over the spacer line the way a layout would, in each order.
  private fun spacerHeight(vararg spans: AndroidLineHeightSpan): Int {
    val fm =
      Paint.FontMetricsInt().apply {
        top = -18
        ascent = -15
        descent = 4
        bottom = 5
      }
    spans.forEach { it.chooseHeight(text, SPACER, SPACER + 1, SPACER, 0, fm) }
    return fm.descent - fm.ascent
  }

  @Test
  fun spacerLineIsMarginBottomTallInEitherSpanOrder() {
    assertEquals(MARGIN_BOTTOM.toInt(), spacerHeight(lineHeight, marginBottom))
    assertEquals(MARGIN_BOTTOM.toInt(), spacerHeight(marginBottom, lineHeight))
  }

  @Test
  fun lineHeightStillAppliesToTextLines() {
    val fm =
      Paint.FontMetricsInt().apply {
        ascent = -15
        descent = 4
      }
    lineHeight.chooseHeight(text, 0, SPACER, 0, 0, fm)
    assertEquals(LINE_HEIGHT.toInt(), fm.descent - fm.ascent)
  }

  private companion object {
    const val LINE_HEIGHT = 60f
    const val MARGIN_BOTTOM = 10f
    const val SPACER = 10
  }
}
