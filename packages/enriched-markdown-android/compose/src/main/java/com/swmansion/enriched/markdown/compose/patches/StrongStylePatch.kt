package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toStyleWeight
import com.swmansion.enriched.markdown.styles.StrongStyle

@Immutable
internal data class StrongStylePatch(
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
) {
  fun apply(
    base: StrongStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): StrongStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
    )
}

@MarkdownStyleDsl
class StrongStyleScope internal constructor() {
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null

  internal fun toPatch(): StrongStylePatch =
    StrongStylePatch(
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
    )

  internal companion object {
    fun merge(
      existing: StrongStylePatch?,
      block: StrongStyleScope.() -> Unit,
    ): StrongStylePatch {
      val scope =
        StrongStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
