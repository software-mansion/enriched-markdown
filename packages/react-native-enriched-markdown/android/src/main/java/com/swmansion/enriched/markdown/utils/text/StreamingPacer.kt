package com.swmansion.enriched.markdown.utils.text

import android.view.Choreographer

/**
 * Paces a streaming view's markdown word by word with the core's StreamingPacer (StreamingPacer.hpp):
 * the view renders what has been revealed, and is handed more every frame while words are waiting,
 * so its text, layout and blocks grow word by word instead of in the bursts the markdown arrives in.
 * [reveal] gets the markdown to render once more of it is revealed; [done] runs once the stream has
 * ended and its last words have appeared. Both on the main thread.
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
  private var frameScheduled = false

  // Without the native library: the streaming prop last given, so the stream still ends once.
  private var streamingWithoutPacer = false

  /**
   * Takes the view's [markdown], its streaming prop and streamingConfig.smooth (the core's
   * StreamingPacer::update). Returns whether the stream ends now; otherwise, once it has ended,
   * [done] runs when its last words have appeared.
   */
  fun update(
    markdown: String,
    streaming: Boolean,
    smooth: Boolean,
  ): Boolean {
    this.markdown = markdown
    if (handle == 0L) {
      shown = markdown.length
      val ends = streamingWithoutPacer && !streaming
      streamingWithoutPacer = streaming
      return ends
    }
    val now = StreamingEffects.now()
    val ends = nativeUpdate(handle, markdown, streaming, smooth, now)
    // What nothing holds back shows at once. New words wait for the next frame: revealing here as
    // well would render twice a frame.
    if (!nativeWaiting(handle, now)) shown = nativeRevealed(handle, now).coerceAtMost(markdown.length)
    runFramesWhileWaiting(now)
    return ends
  }

  /** The part of [markdown] to render now. */
  val markdownToRender: String get() = if (shown >= markdown.length) markdown else markdown.substring(0, shown)

  fun release() {
    if (frameScheduled) Choreographer.getInstance().removeFrameCallback(this)
    frameScheduled = false
    if (handle != 0L) {
      nativeDestroy(handle)
      handle = 0L
    }
  }

  override fun doFrame(frameTimeNanos: Long) {
    frameScheduled = false
    // Released in a frame whose callbacks were already taken.
    if (handle == 0L) return
    val now = StreamingEffects.now()
    val before = shown
    shown = nativeRevealed(handle, now).coerceAtMost(markdown.length)
    runFramesWhileWaiting(now)
    // The frame that ends the stream renders once, through done.
    if (nativeDrained(handle, now)) {
      done()
    } else if (shown != before) {
      reveal(markdownToRender)
    }
  }

  // Runs frame callbacks while words are waiting.
  private fun runFramesWhileWaiting(now: Double) {
    if (nativeWaiting(handle, now)) {
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
    // Each reveal renders the words it shows: about 30 a second keeps words flowing (they fade in
    // at the display's rate) without rendering more often than a stream's own updates would.
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

    @JvmStatic private external fun nativeUpdate(
      handle: Long,
      markdown: String,
      streaming: Boolean,
      smooth: Boolean,
      time: Double,
    ): Boolean

    @JvmStatic private external fun nativeDrained(
      handle: Long,
      time: Double,
    ): Boolean

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
