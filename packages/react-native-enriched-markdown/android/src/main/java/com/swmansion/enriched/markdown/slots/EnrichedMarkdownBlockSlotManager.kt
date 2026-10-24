package com.swmansion.enriched.markdown.slots

import com.facebook.react.module.annotations.ReactModule
import com.facebook.react.uimanager.ThemedReactContext
import com.facebook.react.uimanager.annotations.ReactProp
import com.facebook.react.views.view.ReactViewGroup
import com.facebook.react.views.view.ReactViewManager

/**
 * The host's slot child. A ReactViewManager, so the slot takes every prop a
 * plain View does (overflow, borders, pointerEvents, hitSlop, ...), plus `slotId`.
 */
@ReactModule(name = EnrichedMarkdownBlockSlotManager.NAME)
class EnrichedMarkdownBlockSlotManager : ReactViewManager() {
  override fun getName(): String = NAME

  override fun createViewInstance(context: ThemedReactContext): ReactViewGroup = EnrichedMarkdownBlockSlotView(context)

  @ReactProp(name = "slotId")
  fun setSlotId(
    view: ReactViewGroup,
    value: String?,
  ) {
    (view as? EnrichedMarkdownBlockSlotView)?.slotId = value ?: ""
  }

  companion object {
    const val NAME = "EnrichedMarkdownBlockSlot"
  }
}
