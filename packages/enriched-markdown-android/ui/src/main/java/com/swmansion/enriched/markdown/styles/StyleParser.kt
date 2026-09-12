package com.swmansion.enriched.markdown.styles

import android.content.Context
import android.graphics.Color

class StyleParser(
  private val context: Context,
  private val allowFontScaling: Boolean = true,
  private val maxFontSizeMultiplier: Float = 0f,
) {
  fun color(hex: String): Int = Color.parseColor(hex)

  fun toPixelFromSP(value: Float): Float {
    val metrics = context.resources.displayMetrics
    val baseDensity = metrics.density

    if (!allowFontScaling) {
      return value * baseDensity
    }

    var fontScale = metrics.scaledDensity / baseDensity
    if (maxFontSizeMultiplier >= 1.0f && fontScale > maxFontSizeMultiplier) {
      fontScale = maxFontSizeMultiplier
    }

    return value * baseDensity * fontScale
  }

  fun toPixelFromDIP(value: Float): Float = value * context.resources.displayMetrics.density
}
