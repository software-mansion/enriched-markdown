package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class TextPressEvent(
  surfaceId: Int,
  viewId: Int,
  private val index: Int,
  private val text: String,
) : Event<TextPressEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val eventData: WritableMap = Arguments.createMap()
    eventData.putInt("index", index)
    eventData.putString("text", text)
    return eventData
  }

  companion object {
    const val EVENT_NAME: String = "onTextPress"
  }
}
