package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.SpoilerStyle

@Immutable
internal data class SpoilerStylePatch(
  val color: Color? = null,
) {
  fun apply(
    base: SpoilerStyle,
    units: StyleUnits,
  ): SpoilerStyle =
    base.copy(
      color = color?.let(units::color) ?: base.color,
    )
}

/**
 * Colors of the overlay that conceals `||spoiler||` text. The effect and its tuning are picked
 * with `EnrichedMarkdownText(spoilerOverlay = ...)`.
 */
@MarkdownStyleDsl
class SpoilerStyleScope internal constructor() {
  /** Color of the particles, and the fill of the solid overlay. */
  var color: Color? = null

  internal fun toPatch(): SpoilerStylePatch =
    SpoilerStylePatch(
      color = color,
    )

  internal companion object {
    fun merge(
      existing: SpoilerStylePatch?,
      block: SpoilerStyleScope.() -> Unit,
    ): SpoilerStylePatch {
      val scope =
        SpoilerStyleScope().apply {
          if (existing != null) {
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
