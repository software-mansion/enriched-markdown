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
import com.swmansion.enriched.markdown.styles.ListStyle

@Immutable
internal data class ListStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val bulletColor: Color? = null,
  val bulletSize: Dp? = null,
  val markerMinWidth: Dp? = null,
  val markerColor: Color? = null,
  val markerFontWeight: FontWeight? = null,
  val gapWidth: Dp? = null,
  val marginStart: Dp? = null,
) {
  fun apply(
    base: ListStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): ListStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      bulletColor = bulletColor?.let(units::color) ?: base.bulletColor,
      bulletSize = bulletSize?.let(units::dp) ?: base.bulletSize,
      markerMinWidth = markerMinWidth?.let(units::dp) ?: base.markerMinWidth,
      markerColor = markerColor?.let(units::color) ?: base.markerColor,
      markerFontWeight = markerFontWeight?.toStyleWeight() ?: base.markerFontWeight,
      gapWidth = gapWidth?.let(units::dp) ?: base.gapWidth,
      marginLeft = marginStart?.let(units::dp) ?: base.marginLeft,
    )
}

@MarkdownStyleDsl
class ListStyleScope internal constructor() {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var bulletColor: Color? = null
  var bulletSize: Dp? = null
  var markerMinWidth: Dp? = null
  var markerColor: Color? = null
  var markerFontWeight: FontWeight? = null
  var gapWidth: Dp? = null
  var marginStart: Dp? = null

  internal fun toPatch(): ListStylePatch =
    ListStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      bulletColor = bulletColor,
      bulletSize = bulletSize,
      markerMinWidth = markerMinWidth,
      markerColor = markerColor,
      markerFontWeight = markerFontWeight,
      gapWidth = gapWidth,
      marginStart = marginStart,
    )

  internal companion object {
    fun merge(
      existing: ListStylePatch?,
      block: ListStyleScope.() -> Unit,
    ): ListStylePatch {
      val scope =
        ListStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            bulletColor = existing.bulletColor
            bulletSize = existing.bulletSize
            markerMinWidth = existing.markerMinWidth
            markerColor = existing.markerColor
            markerFontWeight = existing.markerFontWeight
            gapWidth = existing.gapWidth
            marginStart = existing.marginStart
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
