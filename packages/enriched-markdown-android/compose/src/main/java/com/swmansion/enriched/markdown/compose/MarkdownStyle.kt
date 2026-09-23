package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Immutable
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.styles.StyleConfig

/**
 * An immutable, layered markdown style that resolves to a [StyleConfig] at composition time.
 *
 * Create styles with [markdownStyle] or derive overrides with [merge]. Provide defaults app-wide
 * via [MarkdownTheme], and override per subtree by nesting another [MarkdownTheme].
 *
 * ```
 * val base = markdownStyle { paragraph { fontSize = 16.sp } }
 *
 * val lightStyle = base.merge { paragraph { color = Color(0xFF1A1A1A) } }
 * val darkStyle = base.merge { paragraph { color = Color(0xFFE0E0E0) } }
 * ```
 */
@Immutable
class MarkdownStyle internal constructor(
  private val layers: List<MarkdownStyleLayer>,
) {
  /**
   * Returns a new style that applies [block] on top of this style's layers.
   *
   * Useful for light/dark overrides or scoped tweaks without rebuilding the entire style.
   */
  fun merge(block: MarkdownStyleBuilder.() -> Unit): MarkdownStyle {
    val layer = MarkdownStyleBuilder().apply(block).captureLayer()
    return MarkdownStyle(layers + layer)
  }

  /**
   * Returns a new style with [other]'s layers applied on top of this style's. Values [other]
   * leaves unset keep whatever this style resolved them to.
   */
  fun merge(other: MarkdownStyle): MarkdownStyle = MarkdownStyle(layers + other.layers)

  /** Operator form of [merge]. */
  operator fun plus(other: MarkdownStyle): MarkdownStyle = merge(other)

  internal fun resolve(resolveContext: StyleResolveContext): StyleConfig =
    layers.fold(StyleConfig.default(resolveContext.context)) { config, layer ->
      layer.apply(resolveContext, config)
    }

  override fun equals(other: Any?): Boolean {
    if (this === other) return true
    if (other !is MarkdownStyle) return false
    return layers == other.layers
  }

  override fun hashCode(): Int = layers.hashCode()

  companion object {
    val Default = MarkdownStyle(emptyList())
  }
}
