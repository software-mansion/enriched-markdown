package com.swmansion.enriched.markdown

import android.os.Looper
import com.swmansion.enriched.markdown.events.StreamingEndEvent
import com.swmansion.enriched.markdown.test.EventRecordingContext
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode

// No JNI on the JVM: blank markdown renders (parses to nothing); streams stay empty to skip the native filter.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class StreamingEndEventTest {
  private class Host(
    private val name: String,
    private val events: List<String>,
    val set: (markdown: String, streaming: Boolean) -> Unit,
    val cleanup: () -> Unit,
  ) {
    val ends get() = events.count { it == StreamingEndEvent.EVENT_NAME }

    override fun toString() = name
  }

  private fun markdownHost(): Pair<Host, EnrichedMarkdown> {
    val events = mutableListOf<String>()
    val view = EnrichedMarkdown(EventRecordingContext.create(RuntimeEnvironment.getApplication(), events))
    view.id = 1
    view.setMarkdownStyle(MarkdownRenderTestSupport.exportStyleMap())
    val host =
      Host("EnrichedMarkdown", events, { markdown, streaming ->
        view.setMarkdownContent(markdown)
        view.setStreamingProp(streaming)
        view.commitProps()
      }, view::cleanup)
    return host to view
  }

  private fun textHost(): Host {
    val events = mutableListOf<String>()
    val view = EnrichedMarkdownText(EventRecordingContext.create(RuntimeEnvironment.getApplication(), events))
    view.id = 2
    view.setMarkdownStyle(MarkdownRenderTestSupport.exportStyleMap())
    return Host("EnrichedMarkdownText", events, { markdown, streaming ->
      view.setMarkdownContent(markdown)
      view.setStreaming(streaming)
      view.commitProps()
    }, view::cleanup)
  }

  private fun hosts() = listOf(markdownHost().first, textHost())

  // Renders run on the view's executor and apply on the main looper.
  private fun awaitUntil(
    timeoutMs: Long = 5000,
    condition: () -> Boolean,
  ): Boolean {
    val deadline = System.currentTimeMillis() + timeoutMs
    while (true) {
      shadowOf(Looper.getMainLooper()).idle()
      if (condition()) return true
      if (System.currentTimeMillis() > deadline) return false
      Thread.sleep(5)
    }
  }

  private fun settle() = awaitUntil(300) { false }

  @Test
  fun endsOnceAfterTheFinalRenderApplies() {
    for (host in hosts()) {
      host.set("", true)
      host.set(" ", false)
      assertEquals("$host ended before the final render applied", 0, host.ends)
      assertTrue("$host never ended", awaitUntil { host.ends > 0 })
      settle()
      assertEquals("$host", 1, host.ends)
    }
  }

  @Test
  fun endsAtOnceWhenNothingIsLeftToRender() {
    for (host in hosts()) {
      host.set("", true)
      host.set("", false)
      assertEquals("$host", 1, host.ends)
      settle()
      assertEquals("$host", 1, host.ends)
    }
  }

  @Test
  fun aRestartedStreamEndsAgain() {
    for (host in hosts()) {
      host.set("", true)
      host.set(" ", false)
      assertTrue("$host", awaitUntil { host.ends == 1 })

      host.set("", false)
      host.set("", true)
      settle()
      assertEquals("$host ended again when the stream restarted", 1, host.ends)
      host.set(" ", false)
      assertTrue("$host did not end the second stream", awaitUntil { host.ends == 2 })
      settle()
      assertEquals("$host", 2, host.ends)
    }
  }

  // Only EnrichedMarkdown: EnrichedMarkdownText re-renders the old text on restart, hitting the native filter.
  @Test
  fun aStreamRestartedBeforeItsFinalRenderAppliesEndsOnce() {
    val (host, view) = markdownHost()
    host.set("", true)
    host.set(" ", false)
    view.setMarkdownContent("")
    view.setStreamingProp(true)
    assertEquals("the restart ends the stream before it", 1, host.ends)
    view.commitProps()
    settle()
    assertEquals(1, host.ends)

    host.set(" ", false)
    assertTrue("the second stream did not end", awaitUntil { host.ends == 2 })
    settle()
    assertEquals(2, host.ends)
  }

  @Test
  fun aViewThatNeverStreamedDoesNotEnd() {
    for (host in hosts()) {
      host.set(" ", false)
      host.set("  ", false)
      settle()
      assertEquals("$host", 0, host.ends)
    }
  }

  @Test
  fun cleanupMidStreamDoesNotEnd() {
    for (host in hosts()) {
      host.set("", true)
      host.cleanup()
      settle()
      assertEquals("$host", 0, host.ends)
    }
  }

  @Test
  fun cleanupBeforeTheFinalRenderAppliesDoesNotEnd() {
    for (host in hosts()) {
      host.set("", true)
      host.set(" ", false)
      host.cleanup()
      settle()
      assertEquals("$host", 0, host.ends)
    }
  }
}
