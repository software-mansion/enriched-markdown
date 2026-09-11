package com.swmansion.enriched.markdown.input.events

import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.WritableMap
import com.facebook.react.uimanager.events.Event

class OnLinkPressEvent(
  surfaceId: Int,
  viewId: Int,
  private val url: String,
) : Event<OnLinkPressEvent>(surfaceId, viewId) {
  override fun getEventName(): String = EVENT_NAME

  override fun getEventData(): WritableMap =
    Arguments.createMap().apply {
      putString("url", url)
    }

  companion object {
    const val EVENT_NAME = "onLinkPress"
  }
}
