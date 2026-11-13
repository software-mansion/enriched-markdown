package com.swmansion.enriched.markdown.utils.common

import kotlin.math.abs

/**
 * Whether a stream's update on a document with block slots can take the height the view laid out
 * instead of measuring the whole document again, as iOS's ENRMCanTakeLaidOutSlotLayout decides.
 * Heights and positions are px within the host's content box. The walk adds up fractional px and
 * the view whole ones, so their positions drift apart down a long document: a slot the view shows
 * takes the view's position, and only heights are compared.
 */
internal object SlotLayoutReuse {
  /** A block slot as the last full measurement placed it, with the height its child has now. */
  data class MeasuredSlot(
    val id: String,
    val y: Float,
    val height: Float,
    val childHeight: Float,
  )

  /** A block slot placeholder as the view laid it out at the root of its stack. */
  data class ShownSlot(
    val id: String,
    val y: Float,
    val height: Float,
  )

  /**
   * The view must show every slot the measurement placed at the height the measurement reserved
   * for it, which its child still has, and no slot the measurement doesn't know. With [smooth], a
   * slot pacing has not revealed yet is not shown and must lie below [laidOutHeight]; otherwise a
   * slot the view doesn't show (nested in a quote, or placed but not applied yet) fails.
   */
  fun canTake(
    smooth: Boolean,
    laidOutHeight: Float,
    measured: List<MeasuredSlot>,
    shown: List<ShownSlot>,
    tolerance: Float,
  ): Boolean {
    if (laidOutHeight <= 0f || measured.isEmpty()) return false
    var matched = 0
    for (slot in measured) {
      val view = shown.firstOrNull { it.id == slot.id }
      if (view == null) {
        if (!smooth || slot.y < laidOutHeight - tolerance) return false
        continue
      }
      // The view's height went through dp; the child's is measured as the walk measured it.
      if (abs(view.height - slot.height) > tolerance || abs(slot.childHeight - slot.height) > 0.5f) return false
      matched++
    }
    return matched == shown.size
  }

  /**
   * A code block still streaming into the last slot (the snapshot ends inside its open fence) is
   * the document's end, so its child's growth is the document's: the view's height changes by what
   * the child grew. The view must show every slot as [canTake] checks, the last at the height it
   * reserved, and end there with what followed it at the last full measurement ([measuredHeight]).
   * Returns 0 when that doesn't hold.
   */
  fun growingTailHeight(
    endsInsideOpenFence: Boolean,
    measuredHeight: Float,
    laidOutHeight: Float,
    measured: List<MeasuredSlot>,
    shown: List<ShownSlot>,
    tolerance: Float,
  ): Float {
    if (!endsInsideOpenFence || measured.isEmpty() || shown.isEmpty()) return 0f
    val last = measured.last()
    val shownLast = shown.last()
    val trailing = measuredHeight - (last.y + last.height)
    if (shownLast.id != last.id || abs(laidOutHeight - (shownLast.y + shownLast.height) - trailing) > tolerance) return 0f
    val others = measured.dropLast(1) + last.copy(childHeight = last.height)
    if (!canTake(smooth = false, laidOutHeight, others, shown, tolerance)) return 0f
    return laidOutHeight + last.childHeight - shownLast.height
  }
}
