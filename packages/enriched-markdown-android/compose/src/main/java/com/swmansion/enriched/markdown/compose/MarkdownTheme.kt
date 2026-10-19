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
 * Provides [style] as the default for the [content] subtree via [LocalMarkdownStyle].
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
  style: MarkdownStyle,
  content: @Composable () -> Unit,
) {
  CompositionLocalProvider(LocalMarkdownStyle provides style) {
    content()
  }
}

/**
 * Creates and remembers a [MarkdownStyle], rebuilt when [MaterialTheme.colorScheme] or any of
 * [keys] changes.
 *
 * [block] is not composable, so it cannot read `MaterialTheme` itself. Read the scheme first and
 * build the style in a plain `remember` keyed on it:
 *
 * ```
 * val colorScheme = MaterialTheme.colorScheme
 * val style = remember(colorScheme) {
 *   markdownStyle { link { color = colorScheme.primary } }
 * }
 * ```
 *
 * For a style colored from the whole scheme, use
 * [com.swmansion.enriched.markdown.compose.material3.rememberMaterialMarkdownStyle].
 */
@Deprecated(
  message =
    "Use rememberMaterialMarkdownStyle() for a style colored from the Material scheme, or " +
      "remember(keys) { markdownStyle(block) } for any other style read from composition.",
  replaceWith =
    ReplaceWith(
      "remember(MaterialTheme.colorScheme, *keys) { markdownStyle(block) }",
      "androidx.compose.material3.MaterialTheme",
      "androidx.compose.runtime.remember",
      "com.swmansion.enriched.markdown.compose.markdownStyle",
    ),
)
@Composable
fun rememberMarkdownStyle(
  vararg keys: Any?,
  block: MarkdownStyleBuilder.() -> Unit,
): MarkdownStyle {
  val colorScheme = MaterialTheme.colorScheme
  return remember(colorScheme, *keys) { markdownStyle(block) }
}
