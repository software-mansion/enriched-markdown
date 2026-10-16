package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.FontFamilyResolver
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.compose.style.toStyleTableAlignment
import com.swmansion.enriched.markdown.compose.style.toStyleWeight
import com.swmansion.enriched.markdown.styles.TableStyle

@Immutable
internal data class TableStylePatch(
  val fontSize: TextUnit? = null,
  val fontFamily: FontFamily? = null,
  val fontWeight: FontWeight? = null,
  val color: Color? = null,
  val lineHeight: TextUnit? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val headerFontFamily: FontFamily? = null,
  val headerBackgroundColor: Color? = null,
  val headerTextColor: Color? = null,
  val rowEvenBackgroundColor: Color? = null,
  val rowOddBackgroundColor: Color? = null,
  val borderColor: Color? = null,
  val borderWidth: Dp? = null,
  val cornerRadius: Dp? = null,
  val cellPaddingHorizontal: Dp? = null,
  val cellPaddingVertical: Dp? = null,
  val horizontalOverflow: Dp? = null,
  val alignment: Alignment.Horizontal? = null,
) {
  fun apply(
    base: TableStyle,
    resolveContext: StyleResolveContext,
    units: StyleUnits,
  ): TableStyle =
    base.copy(
      fontSize = fontSize?.let(units::sp) ?: base.fontSize,
      fontFamily = fontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.fontFamily,
      fontWeight = fontWeight?.toStyleWeight() ?: base.fontWeight,
      color = color?.let(units::color) ?: base.color,
      lineHeight = lineHeight?.let(units::sp) ?: base.lineHeight,
      marginTop = marginTop?.let(units::dp) ?: base.marginTop,
      marginBottom = marginBottom?.let(units::dp) ?: base.marginBottom,
      headerFontFamily = headerFontFamily?.let { FontFamilyResolver.resolve(it, resolveContext) } ?: base.headerFontFamily,
      headerBackgroundColor = headerBackgroundColor?.let(units::color) ?: base.headerBackgroundColor,
      headerTextColor = headerTextColor?.let(units::color) ?: base.headerTextColor,
      rowEvenBackgroundColor = rowEvenBackgroundColor?.let(units::color) ?: base.rowEvenBackgroundColor,
      rowOddBackgroundColor = rowOddBackgroundColor?.let(units::color) ?: base.rowOddBackgroundColor,
      borderColor = borderColor?.let(units::color) ?: base.borderColor,
      borderWidth = borderWidth?.let(units::dp) ?: base.borderWidth,
      borderRadius = cornerRadius?.let(units::dp) ?: base.borderRadius,
      cellPaddingHorizontal = cellPaddingHorizontal?.let(units::dp) ?: base.cellPaddingHorizontal,
      cellPaddingVertical = cellPaddingVertical?.let(units::dp) ?: base.cellPaddingVertical,
      horizontalOverflow = horizontalOverflow?.let(units::dp) ?: base.horizontalOverflow,
      align = alignment?.toStyleTableAlignment() ?: base.align,
    )
}

@MarkdownStyleDsl
class TableStyleScope internal constructor() {
  var fontSize: TextUnit? = null
  var fontFamily: FontFamily? = null
  var fontWeight: FontWeight? = null
  var color: Color? = null
  var lineHeight: TextUnit? = null
  var marginTop: Dp? = null
  var marginBottom: Dp? = null
  var headerFontFamily: FontFamily? = null
  var headerBackgroundColor: Color? = null
  var headerTextColor: Color? = null
  var rowEvenBackgroundColor: Color? = null
  var rowOddBackgroundColor: Color? = null
  var borderColor: Color? = null
  var borderWidth: Dp? = null
  var cornerRadius: Dp? = null
  var cellPaddingHorizontal: Dp? = null
  var cellPaddingVertical: Dp? = null
  var horizontalOverflow: Dp? = null

  /**
   * Horizontal placement of a table narrower than the space available to it.
   *
   * [Alignment.Start] and [Alignment.End] follow the reading direction;
   * [androidx.compose.ui.AbsoluteAlignment] pins a side regardless of it.
   */
  var alignment: Alignment.Horizontal? = null

  internal fun toPatch(): TableStylePatch =
    TableStylePatch(
      fontSize = fontSize,
      fontFamily = fontFamily,
      fontWeight = fontWeight,
      color = color,
      lineHeight = lineHeight,
      marginTop = marginTop,
      marginBottom = marginBottom,
      headerFontFamily = headerFontFamily,
      headerBackgroundColor = headerBackgroundColor,
      headerTextColor = headerTextColor,
      rowEvenBackgroundColor = rowEvenBackgroundColor,
      rowOddBackgroundColor = rowOddBackgroundColor,
      borderColor = borderColor,
      borderWidth = borderWidth,
      cornerRadius = cornerRadius,
      cellPaddingHorizontal = cellPaddingHorizontal,
      cellPaddingVertical = cellPaddingVertical,
      horizontalOverflow = horizontalOverflow,
      alignment = alignment,
    )

  internal companion object {
    fun merge(
      existing: TableStylePatch?,
      block: TableStyleScope.() -> Unit,
    ): TableStylePatch {
      val scope =
        TableStyleScope().apply {
          if (existing != null) {
            fontSize = existing.fontSize
            fontFamily = existing.fontFamily
            fontWeight = existing.fontWeight
            color = existing.color
            lineHeight = existing.lineHeight
            marginTop = existing.marginTop
            marginBottom = existing.marginBottom
            headerFontFamily = existing.headerFontFamily
            headerBackgroundColor = existing.headerBackgroundColor
            headerTextColor = existing.headerTextColor
            rowEvenBackgroundColor = existing.rowEvenBackgroundColor
            rowOddBackgroundColor = existing.rowOddBackgroundColor
            borderColor = existing.borderColor
            borderWidth = existing.borderWidth
            cornerRadius = existing.cornerRadius
            cellPaddingHorizontal = existing.cellPaddingHorizontal
            cellPaddingVertical = existing.cellPaddingVertical
            horizontalOverflow = existing.horizontalOverflow
            alignment = existing.alignment
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
