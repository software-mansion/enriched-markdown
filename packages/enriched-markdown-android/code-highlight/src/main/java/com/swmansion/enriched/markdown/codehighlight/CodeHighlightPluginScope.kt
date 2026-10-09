package com.swmansion.enriched.markdown.codehighlight

import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.MarkdownPlugins

/**
 * Enables [CodeHighlightPlugin] for every `EnrichedMarkdownText` in [content]; shorthand for
 * `MarkdownPlugins(CodeHighlightPlugin) { ... }`. It shares the object's name, so importing
 * [CodeHighlightPlugin] is enough for `CodeHighlightPlugin { ... }`.
 */
@Composable
fun CodeHighlightPlugin(content: @Composable () -> Unit) {
  MarkdownPlugins(CodeHighlightPlugin, content = content)
}
