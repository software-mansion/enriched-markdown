package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.CodeStyle

@Immutable
internal data class CodeStylePatch(
  val fontFamily: FontFamily? = null,
  val fontSize: TextUnit? = null,
  val color: Color? = null,
  val backgroundColor: Color? = null,
  val borderColor: Color? = null,
) {
  fun apply(
    base: CodeStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): CodeStyle =
    base.copy(
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      color = color?.let(units::color) ?: base.color,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
    )
}

@MarkdownStyleDsl
class CodeStyleScope internal constructor() {
  var fontFamily: FontFamily? = null
  var fontSize: TextUnit? = null
  var color: Color? = null
  var backgroundColor: Color? = null
  var borderColor: Color? = null

  internal fun toPatch(): CodeStylePatch =
    CodeStylePatch(
      fontFamily = fontFamily,
      fontSize = fontSize,
      color = color,
      backgroundColor = backgroundColor,
      borderColor = borderColor,
    )

  internal companion object {
    fun merge(
      existing: CodeStylePatch?,
      block: CodeStyleScope.() -> Unit,
    ): CodeStylePatch {
      val scope =
        CodeStyleScope().apply {
          if (existing != null) {
            fontFamily = existing.fontFamily
            fontSize = existing.fontSize
            color = existing.color
            backgroundColor = existing.backgroundColor
            borderColor = existing.borderColor
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
