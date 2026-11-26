package com.swmansion.enriched.markdown

import com.facebook.react.ReactPackage
import com.facebook.react.ViewManagerOnDemandReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.uimanager.ViewManager
import com.swmansion.enriched.markdown.input.EnrichedMarkdownTextInputManager
import com.swmansion.enriched.markdown.slots.EnrichedMarkdownBlockSlotManager

class EnrichedMarkdownTextPackage :
  ReactPackage,
  ViewManagerOnDemandReactPackage {
  override fun getViewManagerNames(reactContext: ReactApplicationContext): Collection<String> = VIEW_MANAGER_NAMES

  override fun createViewManager(
    reactContext: ReactApplicationContext,
    viewManagerName: String,
  ): ViewManager<*, *>? = createManager(viewManagerName)

  // For setups that still ask for every manager up front.
  override fun createViewManagers(reactContext: ReactApplicationContext): List<ViewManager<*, *>> =
    VIEW_MANAGER_NAMES.mapNotNull { createManager(it) }

  override fun createNativeModules(reactContext: ReactApplicationContext): List<NativeModule> = emptyList()

  internal companion object {
    val VIEW_MANAGER_NAMES =
      listOf(
        EnrichedMarkdownTextManager.NAME,
        EnrichedMarkdownManager.NAME,
        EnrichedMarkdownTextInputManager.NAME,
        EnrichedMarkdownBlockSlotManager.NAME,
      )

    fun createManager(name: String): ViewManager<*, *>? =
      when (name) {
        EnrichedMarkdownTextManager.NAME -> EnrichedMarkdownTextManager()
        EnrichedMarkdownManager.NAME -> EnrichedMarkdownManager()
        EnrichedMarkdownTextInputManager.NAME -> EnrichedMarkdownTextInputManager()
        EnrichedMarkdownBlockSlotManager.NAME -> EnrichedMarkdownBlockSlotManager()
        else -> null
      }
  }
}
