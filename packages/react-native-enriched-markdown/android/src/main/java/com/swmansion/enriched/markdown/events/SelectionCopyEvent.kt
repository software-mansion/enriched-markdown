package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class SelectionCopyEvent(
  surfaceId: Int,
  viewId: Int,
  private val text: String,
  private val format: String,
  private val selectionStart: Int,
  private val selectionEnd: Int,
) : Event<SelectionCopyEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun canCoalesce(): Boolean = false

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply {
      putString("text", text)
      putString("format", format)
      putInt("selectionStart", selectionStart)
      putInt("selectionEnd", selectionEnd)
    }

  companion object {
    const val EVENT_NAME = "onSelectionCopy"
  }
}
