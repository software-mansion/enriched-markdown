package com.swmansion.enriched.markdown.utils.text

import android.text.Spannable
import android.view.Choreographer
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.StreamingEffectSpan
import com.swmansion.enriched.markdown.utils.common.isReducedMotionEnabled
import java.lang.ref.WeakReference
import java.text.BreakIterator

/**
 * Draws a streaming text view's newest characters with the core's effects (fade, gradient): one
 * [StreamingEffectSpan] per run of equal looks, replaced each frame while the looks change over
 * time, and when new text arrives. The text itself is not changed otherwise.
 */
class StreamingEffectsAnimator(
  textView: TextView,
) : Choreographer.FrameCallback {
  private val viewRef = WeakReference(textView)
  private val effects = StreamingEffects()
  private val spans = mutableListOf<StreamingEffectSpan>()
  private var frameScheduled = false
  private var finished = false
  private var tints = IntArray(0)
  private var tintAmounts = FloatArray(0)
  private var opacities = FloatArray(0)

  var type = StreamingEffects.Type.FADE
    private set

  /** Starts over with [config]: 'none' shows what still animates at once. */
  fun configure(config: StreamingEffects.Config) {
    val context = viewRef.get()?.context
    type = if (context != null && isReducedMotionEnabled(context)) StreamingEffects.Type.NONE else config.type
    effects.configure(type, config.durationSeconds, config.length, config.startColor, config.endColor)
    finished = false
    refresh()
  }

  /** The text grew from [start] to [end]. */
  fun noteArrival(
    start: Int,
    end: Int,
  ) {
    val text = viewRef.get()?.text ?: ""
    effects.noteArrival(text, start, end, StreamingEffects.now())
    if (end > start) finished = false
    refresh()
  }

  /** The stream ended: what still animates settles. */
  fun finish() {
    if (finished) return
    finished = true
    effects.finish(StreamingEffects.now())
    refresh()
  }

  fun release() {
    if (frameScheduled) Choreographer.getInstance().removeFrameCallback(this)
    frameScheduled = false
    clearSpans()
    effects.release()
  }

  override fun doFrame(frameTimeNanos: Long) {
    frameScheduled = false
    refresh()
  }

  private fun refresh() {
    val time = StreamingEffects.now()
    applyLooks(time)
    if (effects.changesOverTime(time) && !frameScheduled) {
      frameScheduled = true
      Choreographer.getInstance().postFrameCallback(this)
    }
  }

  private fun applyLooks(time: Double) {
    val textView = viewRef.get() ?: return
    val spannable = textView.text as? Spannable ?: return
    clearSpans()
    textView.invalidate()
    val range = effects.animatedRange(time) ?: return
    val end = (range.last + 1).coerceIn(0, spannable.length)
    var start = range.first.coerceIn(0, end)
    // Spans start and end only between characters: one splitting a character (an emoji) breaks its
    // drawing. The range counts UTF-16 units, so it can start inside one.
    val from = maxOf(0, start - MAX_CHARACTER_LENGTH)
    val characters = BreakIterator.getCharacterInstance().apply { setText(spannable.substring(from, end)) }
    if (start < end && !characters.isBoundary(start - from)) start = from + characters.preceding(start - from)
    val count = end - start
    if (count > 0) {
      if (tints.size < count) {
        tints = IntArray(count)
        tintAmounts = FloatArray(count)
        opacities = FloatArray(count)
      }
      effects.looks(start, count, time, tints, tintAmounts, opacities)
      var runStart = 0

      fun looksLikeRun(i: Int) =
        tints[i] == tints[runStart] && tintAmounts[i] == tintAmounts[runStart] && opacities[i] == opacities[runStart]
      for (i in 1..count) {
        if (i < count && (!characters.isBoundary(start - from + i) || looksLikeRun(i))) continue
        if (tintAmounts[runStart] != 0f || opacities[runStart] != 1f) {
          val span = StreamingEffectSpan(tints[runStart], tintAmounts[runStart], opacities[runStart])
          spannable.setSpan(span, start + runStart, start + i, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
          spans.add(span)
        }
        runStart = i
      }
    }
  }

  private fun clearSpans() {
    val spannable = viewRef.get()?.text as? Spannable
    if (spannable != null) spans.forEach { spannable.removeSpan(it) }
    spans.clear()
  }

  private companion object {
    // How far back a character the range starts inside can begin (an emoji ZWJ sequence).
    const val MAX_CHARACTER_LENGTH = 32
  }
}
