@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.plugin

import android.content.Context
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentSignature
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.FakePayload
import com.swmansion.enriched.markdown.test.FakePlugin
import com.swmansion.enriched.markdown.test.FakeSegmentView
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.latexMathInline
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotSame
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class PluginViewIntegrationTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  @Test
  fun aCustomSegmentIsBuiltAndRecycledByItsOwningPlugin() {
    val plugin = FakePlugin()
    val view = EnrichedMarkdown(context)

    view.applyRenderedSegments(listOf(customSegment(plugin, "x^2")))
    assertEquals(1, plugin.blockSegment.createdViews)
    assertEquals("fake:x^2", (view.getChildAt(0) as FakeSegmentView).text.toString())

    // Same kind, different content: the reconciler keeps the view and updates it in place.
    view.applyRenderedSegments(listOf(customSegment(plugin, "y^2")))
    assertEquals(1, plugin.blockSegment.createdViews)
    assertEquals(1, plugin.blockSegment.updatedViews)
    assertEquals("fake:y^2", (view.getChildAt(0) as FakeSegmentView).text.toString())
  }

  /** A signature is a content hash for view reuse, not an identity: equal blocks each get a view. */
  @Test
  fun identicalSegmentsEachGetAViewOfTheirOwn() {
    val plugin = FakePlugin()
    val view = EnrichedMarkdown(context)

    view.applyRenderedSegments(listOf(customSegment(plugin, "x^2"), customSegment(plugin, "x^2")))

    assertEquals(2, view.childCount)
    assertEquals(2, plugin.blockSegment.createdViews)
    assertNotSame(view.getChildAt(0), view.getChildAt(1))
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
    received.clear()
    view.setOnPluginEventCallback { received.add(it) }
    sink.emit(FakeEvent("boom"))
    assertEquals(listOf(FakeEvent("boom")), received)
  }

  @Test
  fun streamedMarkdownKeepsReportedEventsAndReplacedMarkdownDropsThem() {
    val view = EnrichedMarkdown(context)
    val received = mutableListOf<PluginEvent>()
    view.setOnPluginEventCallback { received.add(it) }
    val sink = view.pluginEventSinkForTest()

    view.setMarkdownContent("a")
    sink.emit(FakeEvent("boom"))
    view.setMarkdownContent("ab")
    sink.emit(FakeEvent("boom"))
    assertEquals(1, received.size)

    view.setMarkdownContent("something else")
    sink.emit(FakeEvent("boom"))
    assertEquals(2, received.size)
  }

  @Test
  fun eventsFromARenderOfReplacedOrRecycledMarkdownAreDropped() {
    val view = EnrichedMarkdown(context)
    val received = mutableListOf<PluginEvent>()
    view.setOnPluginEventCallback { received.add(it) }

    view.setMarkdownContent("a")
    val streamedRender = view.renderPluginEventSink()
    view.setMarkdownContent("ab")
    streamedRender.emit(FakeEvent("streamed"))

    val replacedRender = view.renderPluginEventSink()
    view.setMarkdownContent("something else")
    replacedRender.emit(FakeEvent("replaced"))
    view.renderPluginEventSink().emit(FakeEvent("current"))

    val recycledRender = view.renderPluginEventSink()
    view.prepareForViewReuse()
    view.setOnPluginEventCallback { received.add(it) }
    recycledRender.emit(FakeEvent("recycled"))

    assertEquals(listOf(FakeEvent("streamed"), FakeEvent("current")), received)
  }

  @Test
  fun reportedEventsAreBounded() {
    val view = EnrichedMarkdown(context)
    val received = mutableListOf<PluginEvent>()
    view.setOnPluginEventCallback { received.add(it) }
    val sink = view.pluginEventSinkForTest()

    repeat(1_000) { sink.emit(FakeEvent("event $it")) }
    // The oldest has been evicted, so it counts as new again.
    sink.emit(FakeEvent("event 0"))

    assertEquals(1_001, received.size)
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

  /**
   * A plugin change leaves the AST, and so every segment signature, as it was: the next render must
   * still rebuild the segments rather than keep the views the previous plugins drew.
   */
  @Test
  fun changingThePluginsRebuildsTheSegmentsOfUnchangedMarkdown() {
    val view = EnrichedMarkdown(context)
    val pluginA = FakePlugin(marker = "a")
    view.setPlugins(listOf(pluginA))
    view.applyRenderedSegments(renderAreaFormula(pluginA))
    val firstView = view.getChildAt(0)
    assertTrue(view.renderedText().startsWith("Area [a:r^2:"))

    // An equal list is a no-op, so the next render keeps the view.
    view.setPlugins(listOf(pluginA))
    view.applyRenderedSegments(renderAreaFormula(pluginA))
    assertSame(firstView, view.getChildAt(0))

    val pluginB = FakePlugin(marker = "b")
    view.setPlugins(listOf(pluginB))
    view.applyRenderedSegments(renderAreaFormula(pluginB))
    assertNotSame(firstView, view.getChildAt(0))
    assertTrue(view.renderedText().startsWith("Area [b:r^2:"))

    view.setPlugins(emptyList())
    view.applyRenderedSegments(renderAreaFormula())
    assertEquals("Area \$r^2\$", view.renderedText())
  }

  /** The segments the view's own render lands for `Area $r^2$` once it has parsed it with [plugins] enabled. */
  private fun renderAreaFormula(vararg plugins: MarkdownPlugin): List<RenderedSegment> {
    val snapshot = PluginSnapshot.of(*plugins)
    val ast = document(paragraph(text("Area "), latexMathInline("r^2")))
    return MarkdownSegmentRenderer.render(splitASTIntoSegments(ast, snapshot), StyleConfig.default(context), context, plugins = snapshot)
  }

  private fun EnrichedMarkdown.renderedText(): String {
    assertEquals(1, childCount)
    return (getChildAt(0) as TextView).text.toString()
  }

  private fun customSegment(
    plugin: FakePlugin,
    latex: String,
  ): RenderedSegment.Custom<FakePayload> {
    val source = "fake:$latex"
    return RenderedSegment.Custom(
      pluginId = plugin.id,
      plugin = plugin.blockSegment,
      payload = FakePayload(source),
      signature = SegmentSignature.signatureForPluginSegment(plugin.id, source),
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
