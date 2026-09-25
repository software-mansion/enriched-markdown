package com.swmansion.enriched.markdown.plugin

/**
 * Per-view event a plugin reports to the app (e.g. a LaTeX expression that failed to render).
 *
 * Implementations are deduplicated by equality for the lifetime of a view, so a data class with
 * only content-derived fields keeps streamed content from reporting the same failure per token.
 */
interface PluginEvent {
  val pluginId: String
}

fun interface PluginEventSink {
  fun emit(event: PluginEvent)
}
