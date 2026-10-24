package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.InlineImageStyle

@Immutable
internal data class InlineImageStylePatch(
  val size: Dp? = null,
) {
  fun apply(
    base: InlineImageStyle,
    units: StyleUnits,
  ): InlineImageStyle =
    base.copy(
      size = size?.let(units::dp) ?: base.size,
    )
}

@MarkdownStyleDsl
class InlineImageStyleScope internal constructor() {
  var size: Dp? = null

  internal fun toPatch(): InlineImageStylePatch = InlineImageStylePatch(size = size)

  internal companion object {
    fun merge(
      existing: InlineImageStylePatch?,
      block: InlineImageStyleScope.() -> Unit,
    ): InlineImageStylePatch {
      val scope =
        InlineImageStyleScope().apply {
          if (existing != null) {
            size = existing.size
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
