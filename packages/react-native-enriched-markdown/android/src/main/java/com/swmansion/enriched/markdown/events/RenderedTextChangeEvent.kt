package com.swmansion.enriched.markdown.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event
import com.swmansion.enriched.markdown.highlight.RenderedTextBlock

class RenderedTextChangeEvent(
  surfaceId: Int,
  viewId: Int,
  private val text: String,
  private val blocks: List<RenderedTextBlock>,
) : Event<RenderedTextChangeEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap {
    val blockArray = Arguments.createArray()
    for (block in blocks) {
      val map = Arguments.createMap()
      map.putInt("start", block.start)
      map.putInt("end", block.end)
      map.putString("kind", block.kind)
      blockArray.pushMap(map)
    }
    val eventData: WritableMap = Arguments.createMap()
    eventData.putString("text", text)
    eventData.putArray("blocks", blockArray)
    return eventData
  }

  companion object {
    const val EVENT_NAME: String = "onRenderedTextChange"
  }
}
