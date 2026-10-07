package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.HighlightStyle

@Immutable
internal data class HighlightStylePatch(
  val color: Color? = null,
  val backgroundColor: Color? = null,
) {
  fun apply(
    base: HighlightStyle,
    units: StyleUnits,
  ): HighlightStyle =
    base.copy(
      color = color?.let(units::color) ?: base.color,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
    )
}

@MarkdownStyleDsl
class HighlightStyleScope internal constructor() {
  var color: Color? = null
  var backgroundColor: Color? = null

  internal fun toPatch(): HighlightStylePatch =
    HighlightStylePatch(
      color = color,
      backgroundColor = backgroundColor,
    )

  internal companion object {
    fun merge(
      existing: HighlightStylePatch?,
      block: HighlightStyleScope.() -> Unit,
    ): HighlightStylePatch {
      val scope =
        HighlightStyleScope().apply {
          if (existing != null) {
            color = existing.color
            backgroundColor = existing.backgroundColor
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
