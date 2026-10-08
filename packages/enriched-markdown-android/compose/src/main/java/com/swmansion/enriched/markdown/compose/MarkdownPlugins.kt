package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf

/** The plugins enabled by the enclosing plugin scopes, outermost first. Empty outside every scope. */
val LocalMarkdownPlugins =
  staticCompositionLocalOf<List<MarkdownPlugin>> { emptyList() }

/**
 * Enables this plugin for every [EnrichedMarkdownText] in [content], on top of those the
 * enclosing scopes enable. Scopes nest independently of [MarkdownTheme]:
 *
 * ```
 * LatexMathPlugin {
 *   MarkdownTheme(style = appStyle) {
 *     HomeScreen()
 *   }
 * }
 * ```
 *
 * A scope for a plugin id already enabled outside replaces that plugin rather than adding a second.
 */
@Composable
operator fun MarkdownPlugin.invoke(content: @Composable () -> Unit) {
  val outer = LocalMarkdownPlugins.current
  val plugins = remember(outer, this) { outer.filterNot { it.id == id } + this }
  CompositionLocalProvider(LocalMarkdownPlugins provides plugins, content)
}
