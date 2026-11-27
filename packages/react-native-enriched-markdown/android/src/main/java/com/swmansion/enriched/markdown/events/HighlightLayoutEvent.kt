package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event
import com.swmansion.enriched.markdown.highlight.HighlightRect

class HighlightLayoutEvent(
  surfaceId: Int,
  viewId: Int,
  private val rects: List<HighlightRect>,
) : Event<HighlightLayoutEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  // Each report replaces the last, so a queued one can be dropped.
  override fun canCoalesce(): Boolean = true

  override fun getEventData(): WritableMap {
    val rectArray = Arguments.createArray()
    for (rect in rects) {
      val map = Arguments.createMap()
      map.putInt("index", rect.index)
      map.putDouble("x", rect.x.toDouble())
      map.putDouble("y", rect.y.toDouble())
      map.putDouble("width", rect.width.toDouble())
      map.putDouble("height", rect.height.toDouble())
      rectArray.pushMap(map)
    }
    val eventData: WritableMap = Arguments.createMap()
    eventData.putArray("highlights", rectArray)
    return eventData
  }

  companion object {
    const val EVENT_NAME: String = "onHighlightLayout"
  }
}
