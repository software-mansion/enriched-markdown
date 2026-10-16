package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.ThematicBreakStyle

@Immutable
internal data class ThematicBreakStylePatch(
  val color: Color? = null,
  val height: Dp? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
) {
  fun apply(
    base: ThematicBreakStyle,
    units: StyleUnits,
  ): ThematicBreakStyle =
    base.copy(
      color = color?.let(units::color) ?: base.color,
      height = height?.let(units::dp) ?: base.height,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
    )
}

@MarkdownStyleDsl
class ThematicBreakStyleScope internal constructor() {
  var color: Color? = null
  var height: Dp? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null

  internal fun toPatch(): ThematicBreakStylePatch =
    ThematicBreakStylePatch(
      color = color,
      height = height,
      marginTop = marginTop,
      marginBottom = marginBottom,
    )

  internal companion object {
    fun merge(
      existing: ThematicBreakStylePatch?,
      block: ThematicBreakStyleScope.() -> Unit,
    ): ThematicBreakStylePatch {
      val scope =
        ThematicBreakStyleScope().apply {
          if (existing != null) {
            color = existing.color
            height = existing.height
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
