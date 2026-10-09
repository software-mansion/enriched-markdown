package com.swmansion.enriched.markdown.syntaxhighlighting

import androidx.compose.runtime.Composable
import com.swmansion.enriched.markdown.compose.invoke

/**
 * Enables [SyntaxHighlightingPlugin] for every `EnrichedMarkdownText` in [content]. It shares the
 * object's name, so importing [SyntaxHighlightingPlugin] is enough for
 * `SyntaxHighlightingPlugin { ... }`; without it the call would need the plugin scope operator from
 * `:compose` imported as well.
 */
@Composable
fun SyntaxHighlightingPlugin(content: @Composable () -> Unit) {
  SyntaxHighlightingPlugin.invoke(content)
}
