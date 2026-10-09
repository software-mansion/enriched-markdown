package com.swmansion.enriched.markdown.math

import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.invoke

/**
 * Enables [LatexMathPlugin] for every `EnrichedMarkdownText` in [content]. It shares the object's
 * name, so importing [LatexMathPlugin] is enough for `LatexMathPlugin { ... }`; without it the
 * call would need the plugin scope operator from `:compose` imported as well.
 */
@Composable
fun LatexMathPlugin(content: @Composable () -> Unit) {
  LatexMathPlugin.invoke(content)
}
