@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentSignature
import com.swmansion.enriched.markdown.test.FakePayload
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.FakeSegmentView
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginViewIntegrationTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  @After
  fun tearDown() = EnrichedMarkdownPlugins.reset()

  @Test
  fun aCustomSegmentIsBuiltAndRecycledByItsOwningPlugin() {
    val plugin = FakePlugin()
    EnrichedMarkdownPlugins.install(plugin)
    val view = EnrichedMarkdown(context)

    view.applyRenderedSegments(listOf(customSegment("x^2")))
    assertEquals(1, plugin.blockSegment.createdViews)
    assertEquals("fake:x^2", (view.getChildAt(0) as FakeSegmentView).text.toString())

    // Same kind, different content: the reconciler keeps the view and updates it in place.
    view.applyRenderedSegments(listOf(customSegment("y^2")))
    assertEquals(1, plugin.blockSegment.createdViews)
    assertEquals(1, plugin.blockSegment.updatedViews)
    assertEquals("fake:y^2", (view.getChildAt(0) as FakeSegmentView).text.toString())
  }

  @Test
  fun aSegmentWhosePluginIsGoneDegradesToAnEmptyView() {
    val view = EnrichedMarkdown(context)

    view.applyRenderedSegments(listOf(customSegment("x^2")))

    assertEquals(1, view.childCount)
    assertFalse(view.getChildAt(0) is FakeSegmentView)
  }

  @Test
  fun pluginEventsAreReportedOncePerDistinctEvent() {
    val view = EnrichedMarkdown(context)
    val received = mutableListOf<PluginEvent>()
    view.setOnPluginEventCallback { received.add(it) }

    val sink = view.pluginEventSinkForTest()
    sink.emit(FakeEvent("boom"))
    sink.emit(FakeEvent("boom"))
    sink.emit(FakeEvent("other"))

    assertEquals(listOf(FakeEvent("boom"), FakeEvent("other")), received)

    // Recycling clears both the callback and what it already reported.
    view.prepareForViewReuse()
    view.setOnPluginEventCallback { received.add(it) }
    sink.emit(FakeEvent("boom"))
    assertEquals(3, received.size)
  }

  @Test
  fun anEventEmittedWithNoCallbackIsNotReplayedToALaterOne() {
    val view = EnrichedMarkdown(context)
    val sink = view.pluginEventSinkForTest()

    sink.emit(FakeEvent("boom"))
    val received = mutableListOf<PluginEvent>()
    view.setOnPluginEventCallback { received.add(it) }
    sink.emit(FakeEvent("boom"))

    assertTrue(received.isEmpty())
  }

  private fun customSegment(latex: String): RenderedSegment.Custom {
    val source = "fake:$latex"
    return RenderedSegment.Custom(
      pluginId = FakePlugin.ID,
      payload = FakePayload(source),
      signature = SegmentSignature.signatureForPluginSegment(FakePlugin.ID, source),
    )
  }

  private fun EnrichedMarkdown.pluginEventSinkForTest(): PluginEventSink {
    val field = EnrichedMarkdown::class.java.getDeclaredField("pluginEventSink")
    field.isAccessible = true
    return field.get(this) as PluginEventSink
  }

  private data class FakeEvent(
    val detail: String,
  ) : PluginEvent {
    override val pluginId: String = FakePlugin.ID
  }
}
