package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.StrikethroughStyle

@Immutable
internal data class StrikethroughStylePatch(
  val color: Color? = null,
) {
  fun apply(
    base: StrikethroughStyle,
    units: StyleUnits,
  ): StrikethroughStyle = base.copy(color = color?.let(units::color) ?: base.color)
}

@MarkdownStyleDsl
class StrikethroughStyleScope internal constructor() {
  var color: Color? = null

  internal fun toPatch(): StrikethroughStylePatch = StrikethroughStylePatch(color = color)

  internal companion object {
    fun merge(
      existing: StrikethroughStylePatch?,
      block: StrikethroughStyleScope.() -> Unit,
    ): StrikethroughStylePatch {
      val scope =
        StrikethroughStyleScope().apply {
          if (existing != null) {
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
