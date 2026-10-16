package com.swmansion.enriched.markdown.spoiler

import android.view.Choreographer

/** The frame loop for animations: each draw that still animates requests the next frame. */
internal class SpoilerAnimator(
  private val onFrame: () -> Unit,
) {
  private var isFramePending = false

  private val frameCallback =
    Choreographer.FrameCallback {
      isFramePending = false
      onFrame()
    }

  fun requestFrame() {
    if (isFramePending) return
    isFramePending = true
    Choreographer.getInstance().postFrameCallback(frameCallback)
  }

  fun stop() {
    if (!isFramePending) return
    isFramePending = false
    Choreographer.getInstance().removeFrameCallback(frameCallback)
  }
}
