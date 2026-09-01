package com.swmansion.enriched.markdown.renderer

import android.content.Context
import android.graphics.Typeface
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils

/** Shared style cache for spans to avoid redundant calculations. */
class SpanStyleCache(
  style: StyleConfig,
  private val context: Context,
) {
  val colorsToPreserve: IntArray = buildColorsToPreserve(style)

  val strongFontFamily: String = style.strongStyle.fontFamily
  val strongFontWeight: String = style.strongStyle.fontWeight
  val strongColor: Int? = style.strongStyle.color
  val emphasisFontFamily: String = style.emphasisStyle.fontFamily
  val emphasisFontStyle: String = style.emphasisStyle.fontStyle
  val emphasisColor: Int? = style.emphasisStyle.color
  val strikethroughColor: Int? = style.strikethroughStyle.color
  val underlineColor: Int? = style.underlineStyle.color
  val linkFontFamily: String = style.linkStyle.fontFamily
  val linkColor: Int = style.linkStyle.color
  val linkUnderline: Boolean = style.linkStyle.underline
  val linkBackgroundColor: Int = style.linkStyle.backgroundColor
  val codeFontFamily: String = style.codeStyle.fontFamily
  val codeFontSize: Float = style.codeStyle.fontSize
  val codeColor: Int = style.codeStyle.color

  private fun buildColorsToPreserve(style: StyleConfig): IntArray {
    val paragraphColor = style.paragraphStyle.color
    return buildList {
      style.strongStyle.color
        ?.takeIf { it != 0 }
        ?.let { add(it) }
      style.emphasisStyle.color
        ?.takeIf { it != 0 }
        ?.let { add(it) }
      style.strikethroughStyle.color
        ?.takeIf { it != 0 }
        ?.let { add(it) }
      style.underlineStyle.color
        ?.takeIf { it != 0 }
        ?.let { add(it) }
      style.linkStyle.color
        .takeIf { it != 0 && it != paragraphColor }
        ?.let { add(it) }
      style
        .codeStyle
        .color
        .takeIf { it != 0 }
        ?.let { add(it) }
    }.toIntArray()
  }

  fun getStrongColorFor(blockColor: Int): Int = strongColor ?: blockColor

  fun getEmphasisColorFor(
    blockColor: Int,
    currentColor: Int,
  ): Int =
    if (currentColor == blockColor) {
      emphasisColor ?: blockColor
    } else {
      currentColor
    }

  fun getTypeface(
    fontFamily: String,
    style: Int,
  ): Typeface {
    val base =
      fontFamily
        .takeIf { it.isNotEmpty() }
        ?.let { TypefaceUtils.loadFontFamily(context, it) }
        ?: Typeface.DEFAULT
    return Typeface.create(base, style)
  }

  fun getTypefaceWithWeight(
    fontFamily: String,
    fontWeight: String,
  ): Typeface {
    val style =
      when (fontWeight.lowercase()) {
        "bold", "700", "800", "900" -> Typeface.BOLD
        else -> Typeface.NORMAL
      }
    return getTypeface(fontFamily, style)
  }

  fun getMonospaceTypeface(currentStyle: Int): Typeface = TypefaceUtils.getMonospaceTypeface(context, currentStyle)
}
