package com.swmansion.enriched.markdown.utils.text.span

import android.text.SpannableStringBuilder
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.LineHeightSpan
import com.swmansion.enriched.markdown.spans.MarginBottomSpan
import com.swmansion.enriched.markdown.utils.text.span.SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE
import android.text.style.LineHeightSpan as AndroidLineHeightSpan

fun createLineHeightSpan(lineHeight: Float): AndroidLineHeightSpan = LineHeightSpan(lineHeight)

/**
 * Applies [LineHeightSpan] to [start]..[end] but skips ranges occupied by
 * block [ImageSpan]s (and their trailing '\n'). Without this, the fixed line
 * height would re-clamp the metrics that [ImageSpan.chooseHeight] expanded,
 * causing the image to overflow downward and overlap subsequent content.
 */
fun applyLineHeightSkippingImages(
  builder: SpannableStringBuilder,
  start: Int,
  end: Int,
  lineHeight: Float,
) {
  val blockImageRanges =
    builder
      .getSpans(start, end, ImageSpan::class.java)
      .filter { !it.isInline }
      .map { builder.getSpanStart(it) to builder.getSpanEnd(it) }
      .sortedBy { it.first }

  var pos = start
  for ((imgStart, imgEnd) in blockImageRanges) {
    if (pos < imgStart) {
      builder.setSpan(
        createLineHeightSpan(lineHeight),
        pos,
        imgStart,
        SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
      )
    }
    val skipEnd = if (imgEnd < end && builder[imgEnd] == '\n') imgEnd + 1 else imgEnd
    pos = maxOf(pos, skipEnd)
  }
  if (pos < end) {
    builder.setSpan(
      createLineHeightSpan(lineHeight),
      pos,
      end,
      SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
    )
  }
}

fun applyMarginTop(
  builder: SpannableStringBuilder,
  insertionPoint: Int,
  marginTop: Float,
) {
  if (marginTop <= 0) return

  // Insert a newline character to act as a vertical spacer
  builder.insert(insertionPoint, "\n")

  // Apply MarginBottomSpan to the spacer character to create the gap before the content
  builder.setSpan(
    MarginBottomSpan(marginTop),
    insertionPoint,
    insertionPoint + 1,
    SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
  )
}

fun applyMarginBottom(
  builder: SpannableStringBuilder,
  marginBottom: Float,
) {
  val spacerStart = builder.length
  builder.append("\n")
  // Always create a MarginBottomSpan, even when marginBottom = 0.
  // This ensures removeTrailingMargin can correctly identify the LAST element's
  // margin value. Without a span on the last element, it would pick up a previous
  // element's span (e.g. blockquote with marginBottom: 16) and use that wrong value.
  builder.setSpan(
    MarginBottomSpan(marginBottom),
    spacerStart,
    builder.length,
    SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE,
  )
}
