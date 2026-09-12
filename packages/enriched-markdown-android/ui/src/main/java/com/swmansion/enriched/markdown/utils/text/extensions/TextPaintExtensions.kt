package com.swmansion.enriched.markdown.utils.text.extensions

import android.content.Context
import android.graphics.Typeface
import android.text.TextPaint
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils

fun TextPaint.applyColorPreserving(
  color: Int,
  vararg preserveColors: Int,
) {
  if (this.color !in preserveColors) {
    this.color = color
  }
}

private val typefaceCache = mutableMapOf<String, Typeface>()

fun TextPaint.applyBlockStyleFont(
  blockStyle: BlockStyle,
  context: Context,
) {
  val cacheKey = "${blockStyle.fontFamily}|${blockStyle.fontWeight}"

  val cachedTypeface = typefaceCache[cacheKey]
  if (cachedTypeface != null) {
    this.typeface = cachedTypeface
    return
  }

  val newTypeface =
    TypefaceUtils.applyStyles(
      context = context,
      fontFamily = blockStyle.fontFamily.takeIf { it.isNotEmpty() },
      fontWeight = blockStyle.fontWeight,
    )

  typefaceCache[cacheKey] = newTypeface
  this.typeface = newTypeface
}
