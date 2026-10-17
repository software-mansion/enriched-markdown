package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * The reconciler reuses a placeholder of the same kind for a slot with another
 * id (a streaming tick that changes a URL, say). The reused view has to take the
 * new id, or the heights keyed by id never reach it and it reserves nothing.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class BlockSlotReconcilerTest {
  private val context = RuntimeEnvironment.getApplication()
  private val style by lazy { styleConfig() }

  private fun slot(id: String) = RenderedSegment.BlockSlot(id, BlockSlotKind.IMAGE, signature = id.hashCode().toLong())

  private fun reconcile(
    current: List<BlockSlotSegmentView>,
    next: List<RenderedSegment.BlockSlot>,
  ) = SegmentReconciler.reconcile(
    currentViews = current,
    currentSignatures = current.map { it.slotId.hashCode().toLong() },
    renderedSegments = next,
    reset = false,
    matchesKind = { view, segment ->
      view is BlockSlotSegmentView && segment is RenderedSegment.BlockSlot && view.kind == segment.kind
    },
    createView = { segment ->
      val s = segment as RenderedSegment.BlockSlot
      BlockSlotSegmentView(context, style, s.slotId, s.kind)
    },
    updateView = { view, segment ->
      SegmentViewCreators.updateBlockSlotView(view as BlockSlotSegmentView, segment as RenderedSegment.BlockSlot)
    },
  )

  @Test
  fun aReusedPlaceholderTakesTheNewSlotId() {
    val stale = BlockSlotSegmentView(context, style, "link:aaaa:0", BlockSlotKind.IMAGE)
    val result = reconcile(listOf(stale), listOf(slot("link:bbbb:0")))

    assertSame("same-kind positional reuse keeps the view", stale, result.views.single())
    assertEquals("link:bbbb:0", stale.slotId)
    assertTrue(result.viewsToAttach.isEmpty())
  }

  @Test
  fun heightsKeyedByIdReachTheReusedPlaceholder() {
    val stale = BlockSlotSegmentView(context, style, "link:aaaa:0", BlockSlotKind.IMAGE)
    reconcile(listOf(stale), listOf(slot("link:bbbb:0")))

    val heights = mapOf("link:bbbb:0" to 240)
    stale.slotHeight = heights[stale.slotId] ?: 0
    assertEquals(240, stale.slotHeight)
  }

  @Test
  fun anUnchangedSlotKeepsItsViewAndANewOneIsCreated() {
    val kept = BlockSlotSegmentView(context, style, "image:cccc:0", BlockSlotKind.IMAGE)
    val result = reconcile(listOf(kept), listOf(slot("image:cccc:0"), slot("image:dddd:0")))

    assertSame(kept, result.views[0])
    assertEquals("image:dddd:0", (result.views[1] as BlockSlotSegmentView).slotId)
    assertEquals(1, result.viewsToAttach.size)
  }
}
