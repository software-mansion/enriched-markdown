package com.swmansion.enriched.markdown.input.layout

import com.facebook.react.bridge.Arguments
import com.swmansion.enriched.markdown.input.EnrichedMarkdownTextInputView

class InputLayoutManager(
  private val view: EnrichedMarkdownTextInputView,
) {
  private var forceHeightRecalculationCounter = 0

  fun invalidateLayout() {
    if (view.stateWrapper == null) return

    val text = view.text
    val paint = view.paint

    val needUpdate =
      InputMeasurementStore.store(view.id, text, paint, view.lineSpacingExtra, view.lineSpacingMultiplier)
    if (!needUpdate) return

    val state = Arguments.createMap()
    state.putInt("forceHeightRecalculationCounter", forceHeightRecalculationCounter++)
    view.stateWrapper?.updateState(state)
  }

  fun release() {
    InputMeasurementStore.release(view.id)
  }
}
