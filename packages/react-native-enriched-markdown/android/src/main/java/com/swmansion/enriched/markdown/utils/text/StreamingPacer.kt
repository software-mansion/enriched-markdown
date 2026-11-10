package com.swmansion.enriched.markdown.utils.text

import android.view.Choreographer

/**
 * Paces a streaming view's markdown word by word with the core's StreamingPacer (StreamingPacer.hpp):
 * the view renders what has been revealed, and is handed more every frame while words are waiting,
 * so its text, layout and blocks grow word by word instead of in the bursts the markdown arrives in.
 * [reveal] gets the markdown to render once more of it is revealed; [done] runs once nothing is
 * waiting after [finish]. Both on the main thread.
 */
class StreamingPacer(
  private val reveal: (String) -> Unit,
  private val done: () -> Unit,
) : Choreographer.FrameCallback {
  // 0 without the native library (JVM tests): everything shows at once.
  private var handle: Long =
    try {
      nativeCreate()
    } catch (e: UnsatisfiedLinkError) {
      0L
    }

  /** The whole markdown last given. */
  var markdown = ""
    private set
  private var shown = 0
  private var finishing = false
  private var frameScheduled = false

  /** The part of [markdown] to render now: paced while [pacing] and it continues the last one. */
  fun markdownToRender(
    markdown: String,
    pacing: Boolean,
  ): String {
    val previous = this.markdown.length
    val continues = markdown.length >= previous && markdown.startsWith(this.markdown)
    this.markdown = markdown
    if (handle == 0L) return markdown
    val now = StreamingEffects.now()
    if (!pacing || !continues) {
      nativeReset(handle, markdown.length)
      finishing = false
      update()
      return shownMarkdown()
    }
    if (markdown.length > previous) {
      nativeAppend(handle, previous, markdown.substring(previous), now)
      // Text arriving after the end of the stream drains with the rest.
      if (finishing) nativeFinish(handle, now)
    }
    // The next frame reveals the new words: revealing here as well would render twice a frame.
    runFramesWhileWaiting()
    return shownMarkdown()
  }

  /** The stream ended: what is waiting appears within 200 ms, then [done] runs; nothing runs when nothing waited. */
  fun finish() {
    if (handle == 0L) return
    nativeFinish(handle, StreamingEffects.now())
    update()
    finishing = waiting
  }

  /** Streaming started again: [done] no longer runs for the last [finish]. */
  fun resume() {
    finishing = false
  }

  /** Whether more is still to be revealed. */
  val waiting: Boolean get() = handle != 0L && nativeWaiting(handle, StreamingEffects.now())

  /** Forgets everything and stops (a recycled view). */
  fun reset() {
    if (frameScheduled) Choreographer.getInstance().removeFrameCallback(this)
    frameScheduled = false
    if (handle != 0L) nativeReset(handle, 0)
    markdown = ""
    shown = 0
    finishing = false
  }

  fun release() {
    reset()
    if (handle != 0L) {
      nativeDestroy(handle)
      handle = 0L
    }
  }

  protected fun finalize() {
    if (handle != 0L) nativeDestroy(handle)
  }

  override fun doFrame(frameTimeNanos: Long) {
    frameScheduled = false
    val before = shown
    update()
    if (shown != before) reveal(shownMarkdown())
    if (!frameScheduled && finishing) {
      finishing = false
      done()
    }
  }

  private fun shownMarkdown(): String = if (shown >= markdown.length) markdown else markdown.substring(0, shown)

  // Takes what is revealed now and keeps a frame callback only while words are waiting.
  private fun update() {
    shown = nativeRevealed(handle, StreamingEffects.now()).coerceAtMost(markdown.length)
    runFramesWhileWaiting()
  }

  // Runs frame callbacks while words are waiting or revealed ones are still to be shown.
  private fun runFramesWhileWaiting() {
    val now = StreamingEffects.now()
    if (nativeWaiting(handle, now) || nativeRevealed(handle, now).coerceAtMost(markdown.length) != shown) {
      if (!frameScheduled) {
        frameScheduled = true
        Choreographer.getInstance().postFrameCallbackDelayed(this, REVEAL_INTERVAL_MS)
      }
    } else if (frameScheduled) {
      Choreographer.getInstance().removeFrameCallback(this)
      frameScheduled = false
    }
  }

  private companion object {
    // Each reveal renders the text again: about 30 a second keeps words flowing (they fade in at
    // the display's rate) without rendering more often than a stream's own updates would.
    const val REVEAL_INTERVAL_MS = 25L

    init {
      try {
        System.loadLibrary("react_codegen_EnrichedMarkdownTextSpec")
      } catch (e: UnsatisfiedLinkError) {
        // JVM tests: no native library, everything shows at once.
      }
    }

    @JvmStatic private external fun nativeCreate(): Long

    @JvmStatic private external fun nativeDestroy(handle: Long)

    @JvmStatic private external fun nativeAppend(
      handle: Long,
      start: Int,
      added: String,
      time: Double,
    )

    @JvmStatic private external fun nativeReset(
      handle: Long,
      length: Int,
    )

    @JvmStatic private external fun nativeFinish(
      handle: Long,
      time: Double,
    )

    @JvmStatic private external fun nativeRevealed(
      handle: Long,
      time: Double,
    ): Int

    @JvmStatic private external fun nativeWaiting(
      handle: Long,
      time: Double,
    ): Boolean
  }
}
