package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ParagraphStyle
import com.swmansion.enriched.markdown.spans.SpoilerSpan

/**
 * One line segment of a concealed spoiler, as a [SpoilerSegmentOverlay] sees it. Positions are in
 * the segment's own coordinates, the space the overlay's canvas is in; ranges index the view's
 * text. The view updates it before every draw.
 */
class SpoilerSegment internal constructor(
  /** Start of the whole spoiler, shared by all of its segments. */
  val spoilerStart: Int,
  /** End of the whole spoiler, exclusive. */
  val spoilerEnd: Int,
  /** Start of this segment's slice of the spoiler. */
  val start: Int,
  /** End of this segment's slice, exclusive. */
  val end: Int,
  private val source: Spanned,
) {
  var width: Float = 0f
    internal set
  var height: Float = 0f
    internal set

  /**
   * The line's baseline, from the segment's top. Runs set above or below it (superscript,
   * subscript) keep their shift, which [drawText] reproduces.
   */
  var baseline: Float = 0f
    internal set

  /** Whether the segment's paragraph runs right to left, for effects with a direction to follow. */
  var isRtl: Boolean = false
    internal set

  /** This segment's place among the spoiler's segments, in reading order. */
  var index: Int = 0
    internal set

  /** How many segments the spoiler has. */
  var count: Int = 1
    internal set

  /** The time of the frame being drawn, in [android.os.SystemClock.uptimeMillis] time. */
  var frameTimeMillis: Long = 0L
    internal set

  /** This segment's slice of the text, styled as it looks once revealed, inline styling only. */
  val text: CharSequence by lazy(LazyThreadSafetyMode.NONE) {
    SpannableStringBuilder(source, start, end).apply {
      for (span in getSpans(0, length, Any::class.java)) {
        if (span is SpoilerSpan || span is ParagraphStyle) removeSpan(span)
      }
    }
  }

  private var layout: Layout? = null

  // Where the layout's origin falls in this segment's coordinates.
  private var layoutX = 0f
  private var layoutY = 0f

  /**
   * Draws the segment's text as it looks once revealed, each glyph where the text view draws it,
   * for effects that show the text through (a blur, pixelation). It lays out the whole line each
   * time, so cache the result until [width] or [height] changes.
   */
  fun drawText(canvas: Canvas) {
    val layout = layout ?: return
    // Concealment is the spans' paint alpha; lift it for this one call.
    val spoilers = source.getSpans(start, end, SpoilerSpan::class.java)
    val savedAlphas = FloatArray(spoilers.size) { spoilers[it].textAlpha }
    spoilers.forEach { it.textAlpha = 1f }
    val saveCount = canvas.save()
    try {
      canvas.clipRect(0f, 0f, width, height)
      canvas.translate(layoutX, layoutY)
      layout.draw(canvas)
    } finally {
      canvas.restoreToCount(saveCount)
      spoilers.forEachIndexed { i, span -> span.textAlpha = savedAlphas[i] }
    }
  }

  internal fun place(
    layout: Layout,
    rect: SegmentRect,
    lineBaseline: Float,
    paddingLeft: Float,
    paddingTop: Float,
    isRtl: Boolean,
    index: Int,
    count: Int,
    frameTimeMillis: Long,
  ) {
    this.layout = layout
    width = rect.width
    height = rect.height
    baseline = lineBaseline + paddingTop - rect.top
    layoutX = paddingLeft - rect.left
    layoutY = paddingTop - rect.top
    this.isRtl = isRtl
    this.index = index
    this.count = count
    this.frameTimeMillis = frameTimeMillis
  }
}
