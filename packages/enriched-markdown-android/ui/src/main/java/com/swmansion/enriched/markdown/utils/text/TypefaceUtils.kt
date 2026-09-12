package com.swmansion.enriched.markdown.utils.text

import android.content.Context
import android.graphics.Typeface
import android.os.Build
import java.util.concurrent.ConcurrentHashMap

object TypefaceUtils {
  private val typefaceCache = ConcurrentHashMap<String, Typeface>()

  private val systemFontFamilies =
    setOf(
      "sans-serif",
      "sans-serif-medium",
      "sans-serif-light",
      "sans-serif-thin",
      "sans-serif-condensed",
      "sans-serif-condensed-medium",
      "serif",
      "monospace",
    )

  fun parseFontWeight(fontWeight: String?): Int =
    when (val normalized = fontWeight?.lowercase()) {
      null, "", "normal", "regular", "400" -> 400
      "300", "light" -> 300
      "500", "medium" -> 500
      "600", "semibold" -> 600
      "bold", "700" -> 700
      "800" -> 800
      "900" -> 900
      else -> normalized.toIntOrNull()?.coerceIn(1, 1000) ?: 400
    }

  fun applyStyles(
    base: Typeface?,
    fontWeight: Int,
    fontFamily: String?,
  ): Typeface {
    val family = fontFamily?.takeIf { it.isNotEmpty() }
    val baseTypeface =
      when {
        base != null -> base
        family != null -> Typeface.create(family, Typeface.NORMAL)
        else -> Typeface.DEFAULT
      }
    return createTypefaceWithWeight(baseTypeface, fontWeight)
  }

  fun applyStyles(
    context: Context,
    fontFamily: String?,
    fontWeight: String?,
  ): Typeface {
    val weight = parseFontWeight(fontWeight)
    val family = fontFamily?.takeIf { it.isNotEmpty() }
    val cacheKey = "${family ?: "default"}|$weight"
    return typefaceCache.getOrPut(cacheKey) {
      val base =
        when {
          family == null -> Typeface.DEFAULT
          else -> loadFontFamily(context, family)
        }
      createTypefaceWithWeight(base, weight)
    }
  }

  fun registerComposeFont(
    key: String,
    typeface: Typeface,
  ) {
    typefaceCache["family:$key"] = typeface
  }

  fun loadFontFamily(
    context: Context,
    family: String,
  ): Typeface =
    typefaceCache.getOrPut("family:$family") {
      if (isSystemFontFamily(family)) {
        Typeface.create(family, Typeface.NORMAL)
      } else {
        loadCustomFontFamily(context, family)
      }
    }

  fun getMonospaceTypeface(
    context: Context,
    currentStyle: Int,
  ): Typeface =
    typefaceCache.getOrPut("monospace|$currentStyle") {
      Typeface.create(loadFontFamily(context, "monospace"), currentStyle)
    }

  private fun createTypefaceWithWeight(
    base: Typeface,
    weight: Int,
  ): Typeface =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && weight >= 100) {
      Typeface.create(base, weight, false)
    } else {
      val style = if (weight >= 600) Typeface.BOLD else Typeface.NORMAL
      Typeface.create(base, style)
    }

  private fun isSystemFontFamily(family: String): Boolean =
    family in systemFontFamilies || family.startsWith("sans-serif") || family == "monospace"

  private fun loadCustomFontFamily(
    context: Context,
    family: String,
  ): Typeface {
    val assetPaths =
      listOf(
        "fonts/$family.ttf",
        "fonts/$family.otf",
        "$family.ttf",
        "$family.otf",
      )
    for (path in assetPaths) {
      try {
        return Typeface.createFromAsset(context.assets, path)
      } catch (_: Exception) {
        // Try the next candidate path.
      }
    }

    return Typeface.create(family, Typeface.NORMAL) ?: Typeface.DEFAULT
  }
}
