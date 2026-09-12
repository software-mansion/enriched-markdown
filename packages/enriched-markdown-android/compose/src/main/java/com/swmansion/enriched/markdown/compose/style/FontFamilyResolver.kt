package com.swmansion.enriched.markdown.compose.style

import android.graphics.Typeface
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontListFontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.font.ResourceFont
import androidx.core.content.res.ResourcesCompat

internal object FontFamilyResolver {
  fun resolve(
    fontFamily: FontFamily?,
    resolveContext: StyleResolveContext,
  ): String? {
    if (fontFamily == null) {
      return null
    }

    systemFontFamilyKey(fontFamily)?.let { return it }

    val resourceTypeface = resolveResourceFont(fontFamily, resolveContext)
    if (resourceTypeface != null) {
      return ComposeFontRegistry.register(resourceTypeface)
    }

    val resolvedTypeface =
      resolveContext.fontFamilyResolver
        .resolve(
          fontFamily = fontFamily,
          fontWeight = FontWeight.Normal,
          fontStyle = FontStyle.Normal,
        ).value as? Typeface ?: return null

    return ComposeFontRegistry.register(resolvedTypeface)
  }

  private fun systemFontFamilyKey(fontFamily: FontFamily): String? =
    when (fontFamily) {
      FontFamily.Default, FontFamily.SansSerif -> "sans-serif"
      FontFamily.Serif -> "serif"
      FontFamily.Monospace -> "monospace"
      FontFamily.Cursive -> "cursive"
      else -> null
    }

  private fun resolveResourceFont(
    fontFamily: FontFamily,
    resolveContext: StyleResolveContext,
  ): Typeface? {
    if (fontFamily !is FontListFontFamily) {
      return null
    }

    for (font in fontFamily.fonts) {
      if (font !is ResourceFont) {
        continue
      }

      ResourcesCompat.getFont(resolveContext.context, font.resId)?.let { return it }
    }

    return null
  }
}
