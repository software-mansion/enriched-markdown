package com.swmansion.enriched.markdown

import com.facebook.react.bridge.Arguments

class EnrichedMarkdownTextLayoutManager(
  private val view: EnrichedMarkdownText,
) {
  private var forceHeightRecalculationCounter = 0

  /**
   * Stores the size of the text the view now shows, changed from [changedFrom] on. While a
   * stream grows, the view's own layout has the size: its DynamicLayout reflowed only the edit,
   * where measuring the text would lay all of it out again on every update.
   */
  fun invalidateLayout(changedFrom: Int = 0) {
    // Justified lines measure their natural width in the measurement's layout, not the view's.
    val layout = view.layout.takeIf { view.isStreaming && !view.isJustified }
    val heightChanged =
      layout?.let { MeasurementStore.storeLaidOut(view.id, it, changedFrom, view.trailingMarginBottomPx(), view.renderedMarkdown) }
        ?: MeasurementStore.store(view.id, view.text, view.paint, view.trailingMarginBottomPx(), view.renderedMarkdown)
    if (!heightChanged) return
    val stateWrapper = view.stateWrapper ?: return
    val state = Arguments.createMap()
    state.putInt("forceHeightRecalculationCounter", ++forceHeightRecalculationCounter)
    stateWrapper.updateState(state)
  }

  fun releaseMeasurementStore() {
    MeasurementStore.release(view.id)
  }
}
