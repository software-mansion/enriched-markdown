package com.swmansion.enriched.markdown.input.layout

import android.content.Context
import android.os.Build
import android.text.SpannableStringBuilder
import android.text.StaticLayout
import android.text.TextPaint
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.views.text.TextAttributes
import com.facebook.yoga.YogaMeasureMode
import com.facebook.yoga.YogaMeasureOutput
import com.swmansion.enriched.markdown.input.formatting.InputFormatter
import com.swmansion.enriched.markdown.input.formatting.InputParser
import com.swmansion.enriched.markdown.input.model.BlockRange
import com.swmansion.enriched.markdown.input.spans.applyBodyLineHeightSpan
import com.swmansion.enriched.markdown.utils.input.MarkdownStyleParser
import java.util.concurrent.ConcurrentHashMap

object InputMeasurementStore {
  private data class MeasurementParams(
    val cachedWidth: Float,
    val cachedSize: Long,
    val text: CharSequence?,
    val textAttributes: TextAttributes,
    val hint: CharSequence?,
    val paint: TextPaint,
    val blockRanges: List<BlockRange>,
    val formatter: InputFormatter,
  )

  private val data = ConcurrentHashMap<Int, MeasurementParams>()

  /**
   * [textAttributes] must be a copy the caller no longer mutates: it is kept
   * for re-measuring at other widths.
   */
  internal fun store(
    context: Context,
    id: Int,
    text: CharSequence?,
    textAttributes: TextAttributes,
    hint: CharSequence?,
    paint: TextPaint,
    blockRanges: List<BlockRange>,
    formatter: InputFormatter,
  ): Boolean {
    val cachedWidth = data[id]?.cachedWidth ?: 0f
    val cachedSize = data[id]?.cachedSize ?: 0L

    // The view keeps mutating its own paint (text size, typeface, and the
    // heading size used for the caret on an empty heading line), while this
    // entry is re-measured later for new widths on the layout thread.
    val paintSnapshot = TextPaint(paint)
    val size = measure(context, cachedWidth, text, hint, textAttributes, paintSnapshot, blockRanges, formatter)

    data[id] = MeasurementParams(cachedWidth, size, text, textAttributes, hint, paintSnapshot, blockRanges, formatter)
    return size != cachedSize
  }

  fun release(id: Int) {
    data.remove(id)
  }

  fun getMeasureById(
    context: Context,
    id: Int?,
    width: Float,
    height: Float,
    heightMode: YogaMeasureMode?,
    props: ReadableMap?,
  ): Long {
    val size = getMeasureByIdInternal(context, id, width, props)
    if (heightMode !== YogaMeasureMode.AT_MOST) {
      return size
    }

    val calculatedHeight = YogaMeasureOutput.getHeight(size)
    val atMostHeight = PixelUtil.toDIPFromPixel(height)
    val finalHeight = calculatedHeight.coerceAtMost(atMostHeight)
    return YogaMeasureOutput.make(YogaMeasureOutput.getWidth(size), finalHeight)
  }

  private fun getMeasureByIdInternal(
    context: Context,
    id: Int?,
    width: Float,
    props: ReadableMap?,
  ): Long {
    if (id == null) return initialMeasure(context, width, props)
    val value = data[id] ?: return initialMeasure(context, width, props)

    if (width == value.cachedWidth) {
      return value.cachedSize
    }

    val size =
      measure(
        context,
        width,
        value.text,
        value.hint,
        value.textAttributes,
        value.paint,
        value.blockRanges,
        value.formatter,
      )
    data[id] = value.copy(cachedWidth = width, cachedSize = size)
    return size
  }

  private fun initialMeasure(
    context: Context,
    width: Float,
    props: ReadableMap?,
  ): Long {
    // Measure the rendered plain text, not the raw markdown. A mention link such as
    // [Label](placeholder://x) hides its URL in the source, so measuring the markdown counts those
    // invisible characters and over-estimates the height into extra lines, until the next text
    // change forces a re-measure. Parsing first matches what the editor actually renders.
    val parseResult = InputParser.parseToPlainTextAndRanges(props?.getString("defaultValue").orEmpty())

    val textAttributes = TextAttributes()
    textAttributes.fontSize = props?.positiveFloat("fontSize") ?: DEFAULT_FONT_SIZE_SP
    // lineHeight stays in SP; TextAttributes.effectiveLineHeight converts it
    // to pixels, as React Native does:
    // https://github.com/react/react-native/blob/v0.86.2/packages/react-native/ReactAndroid/src/main/java/com/facebook/react/views/text/TextAttributes.kt#L25
    props?.positiveFloat("lineHeight")?.let { textAttributes.lineHeight = it }

    val formatter = InputFormatter(context.resources.displayMetrics.density)
    formatter.bodyTextAttributes = textAttributes
    props?.getMap("markdownStyle")?.let { markdownStyleMap ->
      formatter.updateStyle(MarkdownStyleParser.parse(markdownStyleMap))
    }

    val paint =
      TextPaint().apply {
        textSize = textAttributes.effectiveFontSize.toFloat()
        isAntiAlias = true
      }

    return measure(
      context,
      width,
      parseResult.plainText,
      props?.getString("placeholder"),
      textAttributes,
      paint,
      parseResult.blockRanges,
      formatter,
    )
  }

  /**
   * Lays out the same spans the editor draws with. [formatter] must already
   * have [textAttributes] as its body text attributes; it is shared with the
   * view, so it is only read here.
   */
  private fun measure(
    context: Context,
    maxWidth: Float,
    text: CharSequence?,
    hint: CharSequence?,
    textAttributes: TextAttributes,
    paint: TextPaint,
    blockRanges: List<BlockRange>,
    formatter: InputFormatter,
  ): Long {
    // An empty editor is measured with its hint, like React Native TextInput:
    // https://github.com/react/react-native/blob/v0.86.2/packages/react-native/ReactAndroid/src/main/java/com/facebook/react/views/textinput/ReactEditText.kt#L1093-L1100
    // With no hint either, StaticLayout still gives the empty text one line
    // from the paint's font metrics, so the field never collapses to 0.
    val hasText = !text.isNullOrEmpty()
    val spannable = SpannableStringBuilder(if (hasText) text else hint ?: "")
    applyBodyLineHeightSpan(spannable, textAttributes)
    if (hasText) {
      formatter.applyBlockFormatting(spannable, blockRanges)
    }

    val widthPx = maxWidth.toInt().coerceAtLeast(0)

    val builder =
      StaticLayout.Builder
        .obtain(spannable, 0, spannable.length, paint, widthPx)
        .setIncludePad(true)
        // Line height comes from InputCssLineHeightSpan / InputHeadingSpan, not
        // extra line spacing.
        .setLineSpacing(0f, 1f)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      builder.setBreakStrategy(android.graphics.text.LineBreaker.BREAK_STRATEGY_HIGH_QUALITY)
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
      builder.setUseLineSpacingFromFallbacks(true)
    }

    val staticLayout = builder.build()
    val heightInDip = PixelUtil.toDIPFromPixel(staticLayout.height.toFloat())
    val widthInDip = PixelUtil.toDIPFromPixel(maxWidth)
    return YogaMeasureOutput.make(widthInDip, heightInDip)
  }

  private fun ReadableMap.positiveFloat(key: String): Float? = if (hasKey(key)) getDouble(key).toFloat().takeIf { it > 0f } else null

  private const val DEFAULT_FONT_SIZE_SP = 16f
}
