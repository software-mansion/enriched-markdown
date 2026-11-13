package com.swmansion.enriched.markdown.utils.common

import com.swmansion.enriched.markdown.utils.common.SlotLayoutReuse.MeasuredSlot
import com.swmansion.enriched.markdown.utils.common.SlotLayoutReuse.ShownSlot
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

// Documents with block slots: the view's height stands when it shows every slot where the last
// full measurement placed it.
class SlotLayoutReuseTest {
  private val tolerance = 1.5f

  private fun takes(
    measured: List<MeasuredSlot>,
    shown: List<ShownSlot>,
    height: Float = 900f,
    smooth: Boolean = false,
  ) = SlotLayoutReuse.canTake(smooth, height, measured, shown, tolerance)

  @Test
  fun aStreamTakesTheViewsHeightWhenEverySlotIsWhereItWasMeasured() {
    val measured = listOf(MeasuredSlot("code:a", 100f, 200f, 200f), MeasuredSlot("code:b", 500f, 120f, 120f))
    val shown = listOf(ShownSlot("code:a", 100f, 200f), ShownSlot("code:b", 501f, 120f))
    assertTrue(takes(measured, shown))
    assertFalse(takes(measured, shown, height = 0f))
    assertFalse(takes(emptyList(), emptyList()))
  }

  // The walk adds up fractional px, the view whole ones: a shown slot takes the view's position.
  @Test
  fun aSlotTheViewMovedTakesTheViewsPosition() {
    assertTrue(takes(listOf(MeasuredSlot("code:a", 96.4f, 200f, 200f)), listOf(ShownSlot("code:a", 100f, 200f))))
  }

  @Test
  fun aSlotThatResizedMeasuresInFull() {
    val shown = listOf(ShownSlot("code:a", 100f, 200f))
    // Its child grew by a pixel.
    assertFalse(takes(listOf(MeasuredSlot("code:a", 100f, 200f, 201f)), shown))
    // Its child grew.
    assertFalse(takes(listOf(MeasuredSlot("code:a", 100f, 200f, 260f)), shown))
    // The view still shows the height it reserved before.
    assertFalse(takes(listOf(MeasuredSlot("code:a", 100f, 240f, 240f)), shown))
  }

  @Test
  fun aSlotTheViewDoesNotShowMeasuresInFullUnlessPacingHidesIt() {
    val measured = listOf(MeasuredSlot("code:a", 100f, 200f, 200f), MeasuredSlot("code:b", 950f, 120f, 120f))
    val shown = listOf(ShownSlot("code:a", 100f, 200f))
    assertFalse(takes(measured, shown))
    assertTrue(takes(measured, shown, smooth = true))
    assertFalse(takes(listOf(MeasuredSlot("code:a", 100f, 200f, 200f), MeasuredSlot("code:b", 600f, 120f, 120f)), shown, smooth = true))
    // The view shows a slot the measurement doesn't know.
    assertFalse(takes(listOf(MeasuredSlot("code:a", 100f, 200f, 200f)), shown + ShownSlot("code:c", 400f, 80f)))
  }

  @Test
  fun aCodeBlockStreamingIntoTheLastSlotGrowsTheDocumentByItsChild() {
    // The last full measurement: the slot at 500, 120 high, 8 below it.
    val measured = listOf(MeasuredSlot("code:a", 100f, 200f, 200f), MeasuredSlot("code:b", 500f, 120f, 160f))
    val shown = listOf(ShownSlot("code:a", 100f, 200f), ShownSlot("code:b", 500f, 120f))
    assertEquals(668f, SlotLayoutReuse.growingTailHeight(true, 628f, 628f, measured, shown, tolerance), 0.001f)
    assertEquals(0f, SlotLayoutReuse.growingTailHeight(false, 628f, 628f, measured, shown, tolerance))
    // The view lays out more after the slot.
    assertEquals(0f, SlotLayoutReuse.growingTailHeight(true, 628f, 700f, measured, shown, tolerance))
    // An image above them loaded: the view moved both, and the document grows from where it ends.
    val moved = listOf(ShownSlot("code:a", 120f, 200f), ShownSlot("code:b", 520f, 120f))
    assertEquals(688f, SlotLayoutReuse.growingTailHeight(true, 628f, 648f, measured, moved, tolerance), 0.001f)
    // The view hasn't applied the last slot's placement yet.
    assertEquals(0f, SlotLayoutReuse.growingTailHeight(true, 628f, 300f, measured, listOf(ShownSlot("code:a", 100f, 200f)), tolerance))
  }

  // A take grew the last slot to 160; the next update arrives before the view laid that out.
  @Test
  fun aSecondTailUpdateBeforeTheViewCaughtUpMeasuresInFull() {
    val measured = listOf(MeasuredSlot("code:a", 100f, 200f, 200f), MeasuredSlot("code:b", 500f, 160f, 200f))
    val shown = listOf(ShownSlot("code:a", 100f, 200f), ShownSlot("code:b", 500f, 120f))
    assertEquals(0f, SlotLayoutReuse.growingTailHeight(true, 668f, 628f, measured, shown, tolerance))
  }
}
