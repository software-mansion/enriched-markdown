package com.swmansion.enriched.markdown.compose

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf

val LocalMarkdownStyle =
  staticCompositionLocalOf { MarkdownStyle.Default }

/**
 * Access the [MarkdownStyle] provided by the nearest enclosing [MarkdownTheme].
 */
object MarkdownTheme {
  val style: MarkdownStyle
    @Composable
    @ReadOnlyComposable
    get() = LocalMarkdownStyle.current
}

/**
 * Provides a default [MarkdownStyle] for the [content] subtree via [LocalMarkdownStyle].
 *
 * Nest [MarkdownTheme] to override styles for part of the UI; inner themes win.
 *
 * ```
 * MarkdownTheme(style = appStyle) {
 *   HomeScreen()
 *   MarkdownTheme(style = compactStyle) {
 *     ChatBubble(markdown = message) // uses compactStyle
 *   }
 * }
 * ```
 */
@Composable
fun MarkdownTheme(
  style: MarkdownStyle = LocalMarkdownStyle.current,
  content: @Composable () -> Unit,
) {
  CompositionLocalProvider(LocalMarkdownStyle provides style) {
    content()
  }
}

/**
 * Creates and remembers a [MarkdownStyle] that tracks [MaterialTheme.colorScheme] changes.
 *
 * Use inside `MaterialTheme { ... }` when style values reference Material tokens:
 *
 * ```
 * MaterialTheme {
 *   MarkdownTheme(style = rememberMarkdownStyle {
 *     paragraph { color = MaterialTheme.colorScheme.onSurface }
 *     link { color = MaterialTheme.colorScheme.primary }
 *   }) {
 *     NavHost(...)
 *   }
 * }
 * ```
 *
 * For static light/dark styles with literal colors, hoist `markdownStyle` / [MarkdownStyle.copy]
 * at file scope instead.
 */
@Composable
fun rememberMarkdownStyle(
  vararg keys: Any?,
  block: MarkdownStyleBuilder.() -> Unit,
): MarkdownStyle {
  val colorScheme = MaterialTheme.colorScheme
  return remember(colorScheme, *keys) { markdownStyle(block) }
}
