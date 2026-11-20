package com.swmansion.enriched.markdown.highlight

import android.view.View
import com.facebook.react.bridge.ReactContext
import com.facebook.react.uimanager.UIManagerHelper
import com.swmansion.enriched.markdown.events.HighlightLayoutEvent
import com.swmansion.enriched.markdown.events.RenderedTextChangeEvent

fun View.emitRenderedTextChange(coordinator: TextHighlightCoordinator) {
  val reactContext = context as? ReactContext ?: return
  val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
  val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)
  dispatcher?.dispatchEvent(
    RenderedTextChangeEvent(surfaceId, id, coordinator.renderedText, coordinator.renderedBlocks),
  )
}

fun View.emitHighlightLayout(rects: List<HighlightRect>) {
  val reactContext = context as? ReactContext ?: return
  val surfaceId = UIManagerHelper.getSurfaceId(reactContext)
  val dispatcher = UIManagerHelper.getEventDispatcherForReactTag(reactContext, id)
  dispatcher?.dispatchEvent(HighlightLayoutEvent(surfaceId, id, rects))
}
