package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toStyleWeight
import com.swmansion.enriched.markdown.styles.CodeBlockStyle

@Immutable
internal data class CodeBlockStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val backgroundColor: Color? = null,
  val borderColor: Color? = null,
  val cornerRadius: Dp? = null,
  val borderWidth: Dp? = null,
  val padding: Dp? = null,
) {
  fun apply(
    base: CodeBlockStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): CodeBlockStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      backgroundColor = backgroundColor?.let(units::color) ?: base.backgroundColor,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
      borderRadius = cornerRadius?.let(units::dp) ?: base.borderRadius,
      borderWidth = borderWidth?.let(units::dp) ?: base.borderWidth,
      padding = padding?.let(units::dp) ?: base.padding,
    )
}

@MarkdownStyleDsl
class CodeBlockStyleScope internal constructor() {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var backgroundColor: Color? = null
  var borderColor: Color? = null
  var cornerRadius: Dp? = null
  var borderWidth: Dp? = null
  var padding: Dp? = null

  internal fun toPatch(): CodeBlockStylePatch =
    CodeBlockStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      backgroundColor = backgroundColor,
      borderColor = borderColor,
      cornerRadius = cornerRadius,
      borderWidth = borderWidth,
      padding = padding,
    )

  internal companion object {
    fun merge(
      existing: CodeBlockStylePatch?,
      block: CodeBlockStyleScope.() -> Unit,
    ): CodeBlockStylePatch {
      val scope =
        CodeBlockStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            backgroundColor = existing.backgroundColor
            borderColor = existing.borderColor
            cornerRadius = existing.cornerRadius
            borderWidth = existing.borderWidth
            padding = existing.padding
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
