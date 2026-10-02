package com.swmansion.enriched.markdown.input.spans

import android.graphics.Paint.FontMetricsInt
import android.text.Spannable
import android.text.style.LineHeightSpan
import android.text.style.UpdateLayout
import com.facebook.react.views.text.TextAttributes
import com.swmansion.enriched.markdown.utils.text.span.applyLineHeight
import kotlin.math.ceil

/**
 * Body line height for the whole input, using the same half-leading metrics as
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
internal class InputLineHeightSpan(
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
    applyLineHeight(fm, lineHeight, start, end, text.length)
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
  text.getSpans(0, text.length, InputLineHeightSpan::class.java).forEach { text.removeSpan(it) }

  val lineHeight = textAttributes.effectiveLineHeight
  if (text.isEmpty() || lineHeight.isNaN()) return

  // SPAN_PRIORITY gives the lowest precedence, so heading line heights and
  // other markdown spans win over the body line height.
  text.setSpan(
    InputLineHeightSpan(lineHeight),
    0,
    text.length,
    Spannable.SPAN_INCLUSIVE_INCLUSIVE or Spannable.SPAN_PRIORITY,
  )
}
