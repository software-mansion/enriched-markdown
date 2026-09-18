package com.swmansion.enriched.markdown.spoiler

import android.graphics.Canvas
import android.graphics.Paint
import android.text.Spanned
import android.text.TextPaint
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import java.lang.ref.WeakReference

class SpoilerOverlayDrawer(
  textView: TextView,
) {
  private val textViewReference = WeakReference(textView)
  val animator = SpoilerAnimator(textView)

  private var strategy: SpoilerStrategy = createStrategy(SpoilerOverlay.PARTICLES)
  private var currentMode: SpoilerOverlay = SpoilerOverlay.PARTICLES

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
      // band it covers with its own metrics rather than the view's.
      metricsPaint.set(ctx.layout.paint)
      span.updateMeasureState(metricsPaint)
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
    strategy.revealSpan(span, ctx) {
      span.markRevealed()
      textViewReference.get()?.invalidate()
      onAllComplete()
    }
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
      backgroundColor = SpoilerDrawContext.resolveBackgroundColor(textView, cachedStyle?.backgroundColor),
    )
  }

  private fun createStrategy(mode: SpoilerOverlay): SpoilerStrategy = mode.createStrategy(animator)

  companion object {
    fun setupIfNeeded(
      textView: TextView,
      styledText: CharSequence,
      existing: SpoilerOverlayDrawer?,
      spoilerOverlay: SpoilerOverlay = SpoilerOverlay.PARTICLES,
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
