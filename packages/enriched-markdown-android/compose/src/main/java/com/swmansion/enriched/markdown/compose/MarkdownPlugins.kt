package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf

/** The plugins enabled by the enclosing plugin scopes, outermost first. Empty outside every scope. */
val LocalMarkdownPlugins =
  staticCompositionLocalOf<List<MarkdownPlugin>> { emptyList() }

/**
 * Enables [plugins] for every [EnrichedMarkdownText] in [content], on top of those the enclosing
 * scopes enable. Scopes nest independently of [MarkdownTheme]:
 *
 * ```
 * MarkdownPlugins(LatexMathPlugin) {
 *   MarkdownTheme(style = appStyle) {
 *     HomeScreen()
 *   }
 * }
 * ```
 *
 * A plugin whose id is already enabled outside replaces that plugin rather than adding a second.
 *
 * Plugin artifacts can ship a scope named after the plugin that delegates here, so
 * `LatexMathPlugin { ... }` is the same as `MarkdownPlugins(LatexMathPlugin) { ... }`.
 */
@Composable
fun MarkdownPlugins(
  vararg plugins: MarkdownPlugin,
  content: @Composable () -> Unit,
) {
  val outer = LocalMarkdownPlugins.current
  val merged =
    remember(outer, *plugins) {
      val ids = plugins.mapTo(HashSet()) { it.id }
      outer.filterNot { it.id in ids } + plugins
    }
  CompositionLocalProvider(LocalMarkdownPlugins provides merged, content)
}
