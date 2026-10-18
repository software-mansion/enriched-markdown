package com.swmansion.enriched.markdown.slots

import android.content.Context
import com.facebook.react.uimanager.PixelUtil
import com.facebook.react.views.view.ReactViewGroup

/** One React replacement for a block; its content is ordinary Fabric children. */
class EnrichedMarkdownBlockSlotView(
  context: Context,
) : ReactViewGroup(context),
  BlockSlotRevealTarget {
  override var slotId: String = ""

  private val revealOverhang = PixelUtil.toPixelFromDIP(REVEAL_OVERHANG_DP).toInt()

  // The slot root never gets a transform style, so translationY is ours alone.
  override fun setReveal(
    offset: Int,
    clipHeight: Int?,
  ) = applyBlockSlotReveal(offset, clipHeight, revealOverhang)

  companion object {
    // Keep in step with ENRMBlockSlotReveal (iOS).
    private const val REVEAL_OVERHANG_DP = 64f
  }
}
