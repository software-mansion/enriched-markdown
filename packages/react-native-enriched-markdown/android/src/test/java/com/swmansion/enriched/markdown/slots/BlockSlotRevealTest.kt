package com.swmansion.enriched.markdown.slots

import android.view.View.MeasureSpec
import com.swmansion.enriched.markdown.segments.BlockSlotKind
import com.swmansion.enriched.markdown.segments.BlockSlotSegmentView
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

/**
 * A slot growing into place: the placeholder lays out its share of the height
 * while measurement keeps the full one, and the slots below it move with it.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class BlockSlotRevealTest {
  private val context = RuntimeEnvironment.getApplication()

  @Test
  fun thePlaceholderLaysOutItsShareOfTheHeight() {
    val placeholder = BlockSlotSegmentView(context, styleConfig(), "image:a:0", BlockSlotKind.IMAGE)
    placeholder.slotHeight = 101
    placeholder.revealFraction = 0.5f
    assertEquals(51, placeholder.revealedHeight)

    placeholder.measure(
      MeasureSpec.makeMeasureSpec(300, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    assertEquals(51, placeholder.measuredHeight)

    placeholder.revealFraction = 1f
    assertEquals(101, placeholder.revealedHeight)
  }

  private class FakeTarget(
    override val slotId: String,
  ) : BlockSlotRevealTarget {
    var offset = -1
    var clipHeight: Int? = -1

    override fun setReveal(
      offset: Int,
      clipHeight: Int?,
    ) {
      this.offset = offset
      this.clipHeight = clipHeight
    }
  }

  private fun placeholder(
    slotId: String,
    height: Int,
  ) = BlockSlotSegmentView(context, styleConfig(), slotId, BlockSlotKind.IMAGE).apply { slotHeight = height }

  @Test
  fun aGrowingSlotMovesTheSlotsBelowIt() {
    val controller = BlockSlotRevealController {}
    val above = placeholder("image:a:0", 100)
    val below = placeholder("image:b:0", 80)
    val aboveTarget = FakeTarget(above.slotId)
    val belowTarget = FakeTarget(below.slotId)
    val unplaced = FakeTarget("image:gone:0")
    val heights = mapOf(above.slotId to 100, below.slotId to 80)

    controller.noteHeights(mapOf(below.slotId to 80), listOf(below), reveal = false)
    controller.noteHeights(heights, listOf(above, below), reveal = true)
    controller.apply(listOf(above, below), listOf(aboveTarget, belowTarget, unplaced))

    assertTrue(above.revealedHeight < 100)
    assertEquals(0, aboveTarget.offset)
    assertEquals(above.revealedHeight, aboveTarget.clipHeight)
    assertEquals(100 - above.revealedHeight, belowTarget.offset)
    assertNull(belowTarget.clipHeight)
    assertEquals(0, unplaced.offset)
    assertNull(unplaced.clipHeight)

    controller.cancel()
    controller.apply(listOf(above, below), listOf(aboveTarget, belowTarget))
    assertEquals(100, above.revealedHeight)
    assertEquals(0, belowTarget.offset)
    assertNull(aboveTarget.clipHeight)
  }

  @Test
  fun aSlotThatLeftGrowsInAgain() {
    val controller = BlockSlotRevealController {}
    val slot = placeholder("image:a:0", 100)
    val heights = mapOf(slot.slotId to 100)

    controller.noteHeights(heights, listOf(slot), reveal = false)
    controller.noteHeights(heights, listOf(slot), reveal = true)
    controller.apply(listOf(slot), emptyList())
    assertEquals(1f, slot.revealFraction)

    controller.keepSlotIds(emptySet())
    controller.noteHeights(heights, listOf(slot), reveal = true)
    controller.apply(listOf(slot), emptyList())
    assertTrue(slot.revealFraction < 1f)
    controller.cancel()
  }
}
