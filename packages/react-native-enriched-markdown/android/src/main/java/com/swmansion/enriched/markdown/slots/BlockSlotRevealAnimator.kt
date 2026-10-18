package com.swmansion.enriched.markdown.slots

import android.animation.ValueAnimator
import android.os.Build
import android.view.Choreographer

/**
 * Linear progress per growing slot, with [onFrame] called every frame meanwhile.
 * Follows the system animator duration scale. Keep in step with
 * ENRMBlockSlotRevealAnimator (iOS).
 */
class BlockSlotRevealAnimator(
  private val onFrame: () -> Unit,
) {
  private val starts = HashMap<String, Long>()
  private var scheduled = false

  // Set while onFrame runs, so one frame reads one time (same base as System.nanoTime).
  private var frameTimeNanos = 0L
  private val frameCallback = Choreographer.FrameCallback { step(it) }

  private val durationNanos: Long
    get() {
      val scale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ValueAnimator.getDurationScale() else 1f
      return (REVEAL_DURATION_MS * 1_000_000L * scale).toLong()
    }

  fun start(slotId: String) {
    starts[slotId] = System.nanoTime()
    schedule()
  }

  /** From 0 to 1 while the slot grows, 1 for any other slot. */
  fun progress(slotId: String): Float {
    val start = starts[slotId] ?: return 1f
    val duration = durationNanos
    if (duration <= 0) return 1f
    val now = if (frameTimeNanos > 0) frameTimeNanos else System.nanoTime()
    return ((now - start).toFloat() / duration).coerceIn(0f, 1f)
  }

  fun cancel() {
    starts.clear()
    if (scheduled) {
      Choreographer.getInstance().removeFrameCallback(frameCallback)
      scheduled = false
    }
  }

  private fun schedule() {
    if (scheduled) return
    scheduled = true
    Choreographer.getInstance().postFrameCallback(frameCallback)
  }

  private fun step(frameTimeNanos: Long) {
    scheduled = false
    this.frameTimeNanos = frameTimeNanos
    // The handler sees the slots that just finished at 1, then they are dropped.
    onFrame()
    val duration = durationNanos
    starts.entries.removeAll { frameTimeNanos - it.value >= duration }
    this.frameTimeNanos = 0L
    if (starts.isNotEmpty()) schedule()
  }

  companion object {
    private const val REVEAL_DURATION_MS = 200L
  }
}
