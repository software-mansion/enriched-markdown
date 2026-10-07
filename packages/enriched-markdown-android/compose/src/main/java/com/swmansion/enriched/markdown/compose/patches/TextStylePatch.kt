package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toStyleTextAlignment
import com.swmansion.enriched.markdown.compose.style.toStyleWeight
import com.swmansion.enriched.markdown.styles.HeadingStyle
import com.swmansion.enriched.markdown.styles.ParagraphStyle

@Immutable
internal data class TextStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val textAlign: TextAlign? = null,
) {
  fun apply(
    base: ParagraphStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): ParagraphStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      textAlign = textAlign?.toStyleTextAlignment() ?: base.textAlign,
    )

  fun apply(
    base: HeadingStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): HeadingStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      textAlign = textAlign?.toStyleTextAlignment() ?: base.textAlign,
    )
}

@MarkdownStyleDsl
class TextStyleScope internal constructor() {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var textAlign: TextAlign? = null

  internal fun toPatch(): TextStylePatch =
    TextStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      textAlign = textAlign,
    )

  internal companion object {
    fun merge(
      existing: TextStylePatch?,
      block: TextStyleScope.() -> Unit,
    ): TextStylePatch {
      val scope =
        TextStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            textAlign = existing.textAlign
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}

typealias ParagraphStyleScope = TextStyleScope
typealias HeadingStyleScope = TextStyleScope
