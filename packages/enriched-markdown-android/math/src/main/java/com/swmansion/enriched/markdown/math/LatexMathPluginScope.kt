package com.swmansion.enriched.markdown.math

import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.MarkdownPlugins

/**
 * Enables [LatexMathPlugin] for every `EnrichedMarkdownText` in [content]; shorthand for
 * `MarkdownPlugins(LatexMathPlugin) { ... }`. It shares the object's name, so importing
 * [LatexMathPlugin] is enough for `LatexMathPlugin { ... }`.
 */
@Composable
fun LatexMathPlugin(content: @Composable () -> Unit) {
  MarkdownPlugins(LatexMathPlugin, content = content)
}
