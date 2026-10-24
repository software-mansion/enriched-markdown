package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toEmphasisStyleString
import com.swmansion.enriched.markdown.styles.EmphasisStyle

@Immutable
internal data class EmphasisStylePatch(
  val fontFamily: FontFamily? = null,
  val fontStyle: FontStyle? = null,
  val color: Color? = null,
) {
  fun apply(
    base: EmphasisStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): EmphasisStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontStyle = fontStyle?.toEmphasisStyleString() ?: base.fontStyle,
      color = color?.let(units::color) ?: base.color,
    )
}

@MarkdownStyleDsl
class EmphasisStyleScope internal constructor() {
  var fontFamily: FontFamily? = null
  var fontStyle: FontStyle? = null
  var color: Color? = null

  internal fun toPatch(): EmphasisStylePatch =
    EmphasisStylePatch(
      fontFamily = fontFamily,
      fontStyle = fontStyle,
      color = color,
    )

  internal companion object {
    fun merge(
      existing: EmphasisStylePatch?,
      block: EmphasisStyleScope.() -> Unit,
    ): EmphasisStylePatch {
      val scope =
        EmphasisStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            fontStyle = existing.fontStyle
            color = existing.color
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
