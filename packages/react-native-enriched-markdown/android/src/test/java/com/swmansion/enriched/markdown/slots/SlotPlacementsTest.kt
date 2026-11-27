package com.swmansion.enriched.markdown.slots

import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The shadow node's slot placements: only placed children stand in for their
 * blocks, and a height the session put on the pixel grid stays on it at a
 * fractional density.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class SlotPlacementsTest {
  private fun placement(
    id: String,
    height: Double,
    placed: Boolean,
  ) = JavaOnlyMap.of("id", id, "height", height, "placed", placed)

  private fun state(vararg placements: JavaOnlyMap) = JavaOnlyMap.of("slotPlacements", JavaOnlyArray.of(*placements))

  @Test
  fun onlyPlacedChildrenClaimTheirBlocks() {
    val placements = SlotPlacements.from(state(placement("a", 40.0, true), placement("b", 0.0, false))) { it * 2f }

    assertEquals(setOf("a", "b"), placements.ids)
    assertEquals(setOf("a"), placements.placed)
    assertEquals(mapOf("a" to 80), placements.heightsPx)
  }

  @Test
  fun aWholePixelHeightStaysWholeAtAFractionalDensity() {
    val density = 2.625f
    // 87 px over the density, as BlockSlotMeasureSession stores it; ceil gave 88.
    val heightDp = (87f / density).toDouble()
    val placements = SlotPlacements.from(state(placement("a", heightDp, true))) { it * density }

    assertEquals(87, placements.heightsPx["a"])
  }

  @Test
  fun noStateMeansNoSlots() {
    val placements = SlotPlacements.from(null)

    assertEquals(emptySet<String>(), placements.ids)
    assertEquals(emptyMap<String, Int>(), placements.heightsPx)
  }
}
