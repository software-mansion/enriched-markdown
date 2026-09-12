package com.swmansion.enriched.markdown.compose.style

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

internal class StyleUnits(
  private val density: Density,
) {
  fun sp(value: TextUnit): Float {
    require(value.type == TextUnitType.Sp) {
      "fontSize and lineHeight must use sp, got ${value.type}"
    }
    return with(density) { value.toPx() }
  }

  fun dp(value: Dp): Float = with(density) { value.toPx() }

  fun color(value: Color): Int = value.toArgb()
}

internal fun FontWeight.toStyleWeight(): String =
  when {
    this >= FontWeight.Bold -> "bold"
    this >= FontWeight.SemiBold -> "600"
    this >= FontWeight.Medium -> "500"
    else -> "normal"
  }

internal fun FontStyle.toEmphasisStyleString(): String =
  when (this) {
    FontStyle.Italic -> "italic"
    else -> "normal"
  }
