package com.swmansion.enriched.markdown.styles

import android.content.Context
import android.graphics.Typeface
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils

/**
 * Styling for GFM tables.
 *
 * [fontSize], [fontFamily], [fontWeight], [color] and [lineHeight] describe body cells; header
 * cells override the family with [headerFontFamily] (falling back to a bold [fontFamily]) and the
 * color with [headerTextColor].
 */
data class TableStyle(
  override val fontSize: Float,
  override val fontFamily: String,
  override val fontWeight: String,
  override val color: Int,
  override val marginTop: Float,
  override val marginBottom: Float,
  override val lineHeight: Float,
  val headerFontFamily: String,
  val headerBackgroundColor: Int,
  val headerTextColor: Int,
  val rowEvenBackgroundColor: Int,
  val rowOddBackgroundColor: Int,
  val borderColor: Int,
  val borderWidth: Float,
  val borderRadius: Float,
  val cellPaddingHorizontal: Float,
  val cellPaddingVertical: Float,
  /** How far the table may bleed horizontally past the container's content box, in pixels. */
  val horizontalOverflow: Float,
  val align: TableAlignment,
) : BaseBlockStyle {
  companion object {
    /** Typeface for body cells, or `null` when the style carries no font family. */
    fun bodyTypeface(
      context: Context,
      style: TableStyle,
    ): Typeface? =
      style.fontFamily
        .takeIf { it.isNotEmpty() }
        ?.let { TypefaceUtils.applyStyles(context, it, style.fontWeight) }

    /**
     * Typeface for header cells: the dedicated header family when set, otherwise the body family
     * forced to bold, otherwise the system bold face.
     */
    fun headerTypeface(
      context: Context,
      style: TableStyle,
    ): Typeface {
      val headerFamily = style.headerFontFamily.takeIf { it.isNotEmpty() }
      if (headerFamily != null) {
        return TypefaceUtils.applyStyles(context, headerFamily, "normal")
      }
      val bodyFamily = style.fontFamily.takeIf { it.isNotEmpty() }
      if (bodyFamily != null) {
        return TypefaceUtils.applyStyles(context, bodyFamily, "bold")
      }
      return Typeface.DEFAULT_BOLD
    }
  }
}
