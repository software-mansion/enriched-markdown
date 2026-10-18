package com.swmansion.enriched.markdown.slots

import android.view.View
import com.swmansion.enriched.markdown.segments.BlockSlotSegmentView
import com.swmansion.enriched.markdown.segments.ContainerNodeView

interface BlockSlotRevealTarget {
  val slotId: String

  fun setReveal(
    offset: Int,
    clipHeight: Int?,
  )
}

/**
 * Grows root block slots into place. The stack lays a growing slot out at a share
 * of its height, while the shadow node places the React children at their final
 * positions, so every child below moves up by what is still missing above it.
 * Nested slots move with their container but do not grow. Keep in step with
 * ENRMBlockSlotRevealController (iOS).
 */
class BlockSlotRevealController(
  durationScale: () -> Float = { 1f },
  onFrame: () -> Unit,
) {
  private val animator = BlockSlotRevealAnimator(durationScale, onFrame)
  private val shownSlotIds = HashSet<String>()

  /** With [reveal], a root slot getting its first height starts growing. */
  fun noteHeights(
    heights: Map<String, Int>,
    segments: List<View>,
    reveal: Boolean,
  ) {
    segments.forEach { view ->
      if (view !is BlockSlotSegmentView || (heights[view.slotId] ?: 0) <= 0) return@forEach
      if (shownSlotIds.add(view.slotId) && reveal) animator.start(view.slotId)
    }
  }

  /** A slot that leaves and comes back (a regenerated answer) grows in again. */
  fun keepSlotIds(slotIds: Set<String>) {
    shownSlotIds.retainAll(slotIds)
  }

  fun apply(
    segments: List<View>,
    targets: List<BlockSlotRevealTarget>,
  ) {
    // Whatever is left here afterwards is reset.
    val pending = targets.associateByTo(HashMap()) { it.slotId }
    var missing = 0
    segments.forEach { view ->
      when (view) {
        is BlockSlotSegmentView -> {
          val progress = animator.progress(view.slotId)
          view.revealFraction = blockSlotRevealEaseOut(progress)
          pending.remove(view.slotId)?.setReveal(missing, if (progress < 1f) view.revealedHeight else null)
          missing += view.slotHeight - view.revealedHeight
        }

        is ContainerNodeView -> {
          if (missing > 0) view.forEachBlockSlot { pending.remove(it.slotId)?.setReveal(missing, null) }
        }
      }
    }
    pending.values.forEach { it.setReveal(0, null) }
  }

  fun cancel() = animator.cancel()

  fun reset() {
    animator.cancel()
    shownSlotIds.clear()
  }
}
