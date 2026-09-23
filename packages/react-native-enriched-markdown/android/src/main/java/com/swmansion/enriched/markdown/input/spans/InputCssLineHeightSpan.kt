package com.swmansion.enriched.markdown.input.spans

import android.graphics.Paint.FontMetricsInt
import android.text.Spannable
import android.text.style.LineHeightSpan
import android.text.style.UpdateLayout
import com.facebook.react.views.text.TextAttributes
import kotlin.math.ceil
import kotlin.math.floor

/**
 * Body line height for the whole input, using the same CSS metrics as
 * React Native's CustomLineHeightSpan.
 *
 * applyFormatting strips and re-adds this span when lists or headings
 * change. EditText rebuilds DynamicLayout only for UpdateLayout (or
 * MetricAffectingSpan) spans so we need to include UpdateLayout to ensure that
 * this happens.
 *
 * Headings apply their own LineHeightSpan at default priority after
 * this one and overwrite these metrics.
 */
internal class InputCssLineHeightSpan(
  lineHeightPx: Float,
) : LineHeightSpan,
  UpdateLayout {
  private val lineHeight: Int = ceil(lineHeightPx.toDouble()).toInt()

  override fun chooseHeight(
    text: CharSequence,
    start: Int,
    end: Int,
    spanstartv: Int,
    v: Int,
    fm: FontMetricsInt,
  ) {
    applyCssLineHeight(fm, lineHeight, start, end, text.length)
  }
}

/**
 * Replaces the body line-height span on [text], like the CustomLineHeightSpan
 * that React Native's addSpansFromStyleAttributes adds for TextInput:
 * https://github.com/react/react-native/blob/v0.86.2/packages/react-native/ReactAndroid/src/main/java/com/facebook/react/views/textinput/ReactEditText.kt#L793-L859
 *
 * React Native also adds font size, color and typeface spans there because
 * its TextLayoutManager measures with a shared paint. The editor draws with
 * its own paint, and InputMeasurementStore measures with a snapshot of it, so
 * line height is the only base style that has to live on the text.
 */
internal fun applyBodyLineHeightSpan(
  text: Spannable,
  textAttributes: TextAttributes,
) {
  text.getSpans(0, text.length, InputCssLineHeightSpan::class.java).forEach { text.removeSpan(it) }

  val lineHeightPx = textAttributes.effectiveLineHeight
  if (text.isEmpty() || lineHeightPx.isNaN()) return

  // SPAN_PRIORITY gives the lowest precedence, so heading line heights and
  // other markdown spans win over the body line height.
  text.setSpan(
    InputCssLineHeightSpan(lineHeightPx),
    0,
    text.length,
    Spannable.SPAN_INCLUSIVE_INCLUSIVE or Spannable.SPAN_PRIORITY,
  )
}

/**
 * CSS-like line height, copied from RN CustomLineHeightSpan so we do
 * not depend on React Native internal span types.
 *
 * Mirrors CustomLineHeightSpan.chooseHeight:
 * https://github.com/react/react-native/blob/v0.86.2/packages/react-native/ReactAndroid/src/main/java/com/facebook/react/views/text/internal/span/CustomLineHeightSpan.kt#L44-L57
 */
internal fun applyCssLineHeight(
  fm: FontMetricsInt,
  lineHeightPx: Int,
  start: Int,
  end: Int,
  textLength: Int,
) {
  val leading = lineHeightPx - ((-fm.ascent) + fm.descent)
  fm.ascent -= ceil(leading / 2.0f).toInt()
  fm.descent += floor(leading / 2.0f).toInt()

  if (start == 0) {
    fm.top = fm.ascent
  }
  if (end == textLength) {
    fm.bottom = fm.descent
  }
}
