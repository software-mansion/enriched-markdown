package com.swmansion.enriched.markdown

import com.facebook.react.bridge.Arguments

class EnrichedMarkdownTextLayoutManager(
  private val view: EnrichedMarkdownText,
) {
  private var forceHeightRecalculationCounter = 0

  /**
   * [changedFrom] is where the shown text changed. While streaming, the size comes from the
   * view's own layout, which reflowed only the edit; measuring would lay all the text out again.
   */
  fun invalidateLayout(changedFrom: Int = 0) {
    // Justified lines measure their natural width in the measurement's layout, not the view's.
    val layout = view.layout.takeIf { view.isStreaming && !view.isJustified }
    val heightChanged =
      layout?.let { MeasurementStore.storeLaidOut(view.id, it, changedFrom, view.trailingMarginBottomPx(), view.renderedMarkdown) }
        ?: MeasurementStore.store(
          view.id,
          view.text,
          view.paint,
          view.trailingMarginBottomPx(),
          view.renderedMarkdown,
          viewWidthPx = view.layout?.width ?: (view.width - view.compoundPaddingLeft - view.compoundPaddingRight).coerceAtLeast(0),
        )
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
