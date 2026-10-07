package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.UnderlineStyle

@Immutable
internal data class UnderlineStylePatch(
  val color: Color? = null,
) {
  fun apply(
    base: UnderlineStyle,
    units: StyleUnits,
  ): UnderlineStyle = base.copy(color = color?.let(units::color) ?: base.color)
}

@MarkdownStyleDsl
class UnderlineStyleScope internal constructor() {
  var color: Color? = null

  internal fun toPatch(): UnderlineStylePatch = UnderlineStylePatch(color = color)

  internal companion object {
    fun merge(
      existing: UnderlineStylePatch?,
      block: UnderlineStyleScope.() -> Unit,
    ): UnderlineStylePatch {
      val scope =
        UnderlineStyleScope().apply {
          if (existing != null) {
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
