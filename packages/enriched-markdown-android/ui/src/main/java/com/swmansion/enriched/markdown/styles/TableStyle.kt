package com.swmansion.enriched.markdown.styles

import android.content.Context
import android.graphics.Typeface
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils

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
  val horizontalOverflow: Float,
  val align: TableAlignment,
) : BaseBlockStyle {
  companion object {
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
