package com.swmansion.enriched.markdown.slots

import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.PixelUtil
import kotlin.math.roundToInt

/**
 * The shadow node's `slotPlacements` state: every slot child's id, the ones it
 * placed (only those stand in for their blocks), and their heights in px.
 */
internal data class SlotPlacements(
  val ids: Set<String>,
  val placed: Set<String>,
  val heightsPx: Map<String, Int>,
) {
  companion object {
    fun from(
      state: ReadableMap?,
      toPixels: (Float) -> Float = PixelUtil::toPixelFromDIP,
    ): SlotPlacements {
      val placements = state?.takeIf { it.hasKey("slotPlacements") }?.getArray("slotPlacements")
      val ids = LinkedHashSet<String>()
      val placed = LinkedHashSet<String>()
      val heights = HashMap<String, Int>()
      for (index in 0 until (placements?.size() ?: 0)) {
        val placement = placements?.getMap(index) ?: continue
        val id = placement.getString("id") ?: continue
        ids += id
        if (placement.hasKey("placed") && placement.getBoolean("placed")) {
          placed += id
          // Whole px over the density: already on the pixel grid, so rounding
          // only removes float error (ceil would add a pixel at 2.625 or 3.5).
          heights[id] = toPixels(placement.getDouble("height").toFloat()).roundToInt()
        }
      }
      return SlotPlacements(ids, placed, heights)
    }
  }
}
