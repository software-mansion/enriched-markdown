package com.swmansion.enriched.markdown.spoiler

import android.animation.ValueAnimator
import android.graphics.Canvas
import android.graphics.Paint
import android.text.Spannable
import android.text.Spanned
import android.text.TextPaint
import android.view.animation.LinearInterpolator
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import java.lang.ref.WeakReference

class SpoilerOverlayDrawer(
  textView: TextView,
) {
  private val textViewReference = WeakReference(textView)
  val animator = SpoilerAnimator(textView)

  private var strategy: SpoilerStrategy = createStrategy(SpoilerOverlay.Particles)
  private var currentMode: SpoilerOverlay = SpoilerOverlay.Particles

  private val activeKeys = mutableSetOf<SegmentKey>()
  private val metricsPaint = TextPaint()
  private val fontMetrics = Paint.FontMetrics()

  private var cachedStyle: SpoilerStyle? = null

  var spoilerOverlay: SpoilerOverlay
    get() = currentMode
    set(value) {
      if (currentMode == value) return
      strategy.stop()
      currentMode = value
      strategy = createStrategy(value)
      cachedStyle?.let { strategy.applyStyle(it) }
      textViewReference.get()?.invalidate()
    }

  fun registerSpans(spans: Array<SpoilerSpan>) {
    if (spans.isEmpty()) return
    val style = spans[0].styleCache.spoilerStyle
    cachedStyle = style
    strategy.applyStyle(style)
  }

  fun draw(canvas: Canvas) {
    val ctx = buildContext() ?: return

    activeKeys.clear()

    for (span in ctx.spans) {
      if (span.revealed) continue
      val spanStart = ctx.text.getSpanStart(span)
      val spanEnd = ctx.text.getSpanEnd(span)
      if (spanStart < 0 || spanEnd < 0 || spanStart >= spanEnd) continue

      // The span may be set in a different size than the view (e.g. in a heading), so measure the
      // band it covers with its block's metrics rather than the view's.
      metricsPaint.set(ctx.layout.paint)
      metricsPaint.textSize = span.blockStyle.fontSize
      metricsPaint.getFontMetrics(fontMetrics)

      val spanIdentity = System.identityHashCode(span)
      val firstLine = ctx.layout.getLineForOffset(spanStart)
      val lastLine = ctx.layout.getLineForOffset(spanEnd)

      for (line in firstLine..lastLine) {
        val segmentStart = maxOf(spanStart, ctx.layout.getLineStart(line))
        val segmentEnd = minOf(spanEnd, ctx.layout.getLineEnd(line))
        if (segmentStart >= segmentEnd) continue

        val rect =
          computeSegmentRect(
            ctx.layout,
            line,
            segmentStart,
            segmentEnd,
            fontMetrics,
            ctx.paddingLeft,
            ctx.paddingTop,
          ) ?: continue
        val key = SegmentKey(spanIdentity, line)
        activeKeys.add(key)

        strategy.drawSegment(canvas, ctx, key, rect)
      }
    }

    strategy.pruneStaleSegments(activeKeys)
  }

  fun revealSpan(
    span: SpoilerSpan,
    onAllComplete: () -> Unit,
  ) {
    val ctx = buildContext()
    if (ctx == null) {
      span.markRevealed()
      onAllComplete()
      return
    }
    span.markRevealing()
    fadeInText(span)
    strategy.revealSpan(span, ctx) {
      span.markRevealed()
      refreshText(span)
      onAllComplete()
    }
  }

  // The text fades in as the overlay fades out, on the same curve.
  private fun fadeInText(span: SpoilerSpan) {
    ValueAnimator.ofFloat(0f, 1f).apply {
      duration = REVEAL_DURATION_MS
      interpolator = LinearInterpolator()
      addUpdateListener { animation ->
        if (span.revealed) return@addUpdateListener
        span.textAlpha = 1f - overlayAlphaAt(animation.animatedFraction)
        refreshText(span)
      }
      start()
    }
  }

  // A selectable TextView caches its rendered text per block, which a plain invalidate() does not
  // refresh; setting the span again marks its range dirty.
  private fun refreshText(span: SpoilerSpan) {
    val textView = textViewReference.get() ?: return
    val text = textView.text as? Spannable
    val start = text?.getSpanStart(span) ?: -1
    if (text != null && start >= 0) {
      text.setSpan(span, start, text.getSpanEnd(span), text.getSpanFlags(span))
    }
    textView.invalidate()
  }

  fun stop() {
    animator.stop()
    strategy.stop()
  }

  private fun buildContext(): SpoilerDrawContext? {
    val textView = textViewReference.get() ?: return null
    val layout = textView.layout ?: return null
    val text = textView.text as? Spanned ?: return null
    val spans = text.getSpans(0, text.length, SpoilerSpan::class.java)
    if (spans.isEmpty()) return null
    return SpoilerDrawContext(
      textView = textView,
      layout = layout,
      text = text,
      spans = spans,
      paddingLeft = textView.totalPaddingLeft.toFloat(),
      paddingTop = textView.totalPaddingTop.toFloat(),
    )
  }

  private fun createStrategy(mode: SpoilerOverlay): SpoilerStrategy = mode.createStrategy(animator)

  companion object {
    fun setupIfNeeded(
      textView: TextView,
      styledText: CharSequence,
      existing: SpoilerOverlayDrawer?,
      spoilerOverlay: SpoilerOverlay = SpoilerOverlay.Particles,
    ): SpoilerOverlayDrawer? {
      if (styledText !is Spanned) return tearDown(existing)
      val spans = styledText.getSpans(0, styledText.length, SpoilerSpan::class.java)
      if (spans.isEmpty()) return tearDown(existing)
      val drawer = existing ?: SpoilerOverlayDrawer(textView)
      drawer.spoilerOverlay = spoilerOverlay
      drawer.registerSpans(spans)
      return drawer
    }

    /**
     * A restyle renders the same content again with fresh spans, so reveals the reader already
     * made are carried over by position whenever the text itself is unchanged.
     */
    fun carryOverReveals(
      previousText: CharSequence?,
      nextText: CharSequence,
    ) {
      if (previousText !is Spanned || nextText !is Spanned) return
      if (previousText.toString() != nextText.toString()) return
      val previous = previousText.spoilerSpansInOrder()
      val next = nextText.spoilerSpansInOrder()
      if (previous.size != next.size) return
      previous.zip(next).forEach { (old, new) ->
        if (old.revealed || old.revealing) new.markRevealed()
      }
    }

    private fun Spanned.spoilerSpansInOrder(): List<SpoilerSpan> =
      getSpans(0, length, SpoilerSpan::class.java).sortedBy { getSpanStart(it) }

    private fun tearDown(existing: SpoilerOverlayDrawer?): Nothing? {
      existing?.stop()
      return null
    }
  }
}
