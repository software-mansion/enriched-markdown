package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.styles.StyleConfig
import kotlin.math.roundToInt

/**
 * Stand-in for a block a React slot child replaces. It only reserves the slot's
 * height in the segment stack (the Fabric child is positioned over it by the
 * host's shadow node) and carries the margins of the block it replaced.
 */
class BlockSlotSegmentView(
  context: Context,
  private val style: StyleConfig,
  // The reconciler reuses a placeholder for another slot of the same kind, so
  // both are updated in place (SegmentViewCreators.updateBlockSlotView).
  var slotId: String,
  var kind: BlockSlotKind,
) : View(context),
  BlockSegmentView {
  var slotHeight: Int = 0
    set(value) {
      if (field == value) return
      field = value
      requestLayout()
    }

  /** The share the stack lays out while the slot grows in; measurement keeps the full height. */
  var revealFraction: Float = 1f
    set(value) {
      if (field == value) return
      field = value
      requestLayout()
    }

  val revealedHeight: Int
    get() = (slotHeight * revealFraction).roundToInt()

  override val segmentMarginTop: Int
    get() = kind.marginTop(style)

  override val segmentMarginBottom: Int
    get() = kind.marginBottom(style)

  init {
    isClickable = false
    isFocusable = false
    importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
  }

  override fun onMeasure(
    widthMeasureSpec: Int,
    heightMeasureSpec: Int,
  ) {
    setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), revealedHeight)
  }
}
