package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ParagraphStyle
import com.swmansion.enriched.markdown.spans.SpoilerSpan

/**
 * The part of a concealed spoiler on one line of text, as a [SpoilerSliceOverlay] sees it: a
 * wrapped spoiler has one slice per line, and one that starts or ends mid-line covers only part of
 * its line. Positions are in the slice's own coordinates, the space the overlay's canvas is in;
 * ranges index the view's text. The view updates it before every draw.
 */
class SpoilerSlice internal constructor(
  /** Start of the whole spoiler, shared by all of its slices. */
  val spoilerStart: Int,
  /** End of the whole spoiler, exclusive. */
  val spoilerEnd: Int,
  /** Start of this slice of the spoiler. */
  val start: Int,
  /** End of this slice, exclusive. */
  val end: Int,
  private val source: Spanned,
) {
  var width: Float = 0f
    internal set
  var height: Float = 0f
    internal set

  /**
   * The text's baseline, from the top. Runs set above or below it (superscript, subscript) keep
   * their shift, which [drawText] reproduces.
   */
  var baseline: Float = 0f
    internal set

  /** Whether the slice's paragraph runs right to left, for effects with a direction to follow. */
  var isRtl: Boolean = false
    internal set

  /** This slice's place among the spoiler's slices, in reading order. */
  var index: Int = 0
    internal set

  /** How many slices the spoiler has, one per line it spans. */
  var count: Int = 1
    internal set

  /** The time of the frame being drawn, in [android.os.SystemClock.uptimeMillis] time. */
  var frameTimeMillis: Long = 0L
    internal set

  /** This slice of the text, styled as it looks once revealed, inline styling only. */
  val text: CharSequence by lazy(LazyThreadSafetyMode.NONE) {
    SpannableStringBuilder(source, start, end).apply {
      for (span in getSpans(0, length, Any::class.java)) {
        if (span is SpoilerSpan || span is ParagraphStyle) removeSpan(span)
      }
    }
  }

  private var layout: Layout? = null

  // Where the layout's origin falls in this slice's coordinates.
  private var layoutX = 0f
  private var layoutY = 0f

  /**
   * Draws the slice's text as it looks once revealed, each glyph where the text view draws it, for
   * effects that show the text through (a blur, pixelation). It lays out the whole line each time,
   * so cache the result until [width] or [height] changes. New content under the slice, such as an
   * image loading, comes with a new overlay.
   *
   * Call it on the main thread, as from [SpoilerSliceOverlay.draw]. It lifts the spoiler's
   * concealment while it draws, so a call from another thread could show the hidden text in the
   * text view's own draw. For heavy work such as a blur, draw the text into a bitmap on the main
   * thread, process the bitmap on another one, and call [SpoilerOverlayHost.invalidate] when the
   * result is ready.
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
    rect: SliceRect,
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
