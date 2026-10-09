package com.swmansion.enriched.markdown.codehighlight

import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.invoke

/**
 * Enables [CodeHighlightPlugin] for every `EnrichedMarkdownText` in [content]. It shares the
 * object's name, so importing [CodeHighlightPlugin] is enough for
 * `CodeHighlightPlugin { ... }`; without it the call would need the plugin scope operator from
 * `:compose` imported as well.
 */
@Composable
fun CodeHighlightPlugin(content: @Composable () -> Unit) {
  CodeHighlightPlugin.invoke(content)
}
