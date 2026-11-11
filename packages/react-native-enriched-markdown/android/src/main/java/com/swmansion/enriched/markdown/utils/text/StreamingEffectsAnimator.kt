package com.swmansion.enriched.markdown.utils.text

import android.text.Spannable
import android.view.Choreographer
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.StreamingEffectSpan
import com.swmansion.enriched.markdown.utils.common.isReducedMotionEnabled
import java.lang.ref.WeakReference

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
  private val runs = StreamingEffectRuns()
  private val spans = mutableListOf<StreamingEffectSpan>()
  private var frameScheduled = false
  private var finished = false

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
    effects.noteArrival(start, end, StreamingEffects.now())
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
    runs.split(
      spannable,
      range,
      { start, count, tints, tintAmounts, opacities -> effects.looks(start, count, time, tints, tintAmounts, opacities) },
    ) { start, end, tint, tintAmount, opacity ->
      val span = StreamingEffectSpan(tint, tintAmount, opacity)
      spannable.setSpan(span, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
      spans.add(span)
    }
  }

  private fun clearSpans() {
    val spannable = viewRef.get()?.text as? Spannable
    if (spannable != null) spans.forEach { spannable.removeSpan(it) }
    spans.clear()
  }
}
