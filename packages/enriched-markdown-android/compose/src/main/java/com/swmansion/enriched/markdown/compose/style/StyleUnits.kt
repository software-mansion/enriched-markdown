package com.swmansion.enriched.markdown.compose.style

import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.TextUnitType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.styles.TableAlignment
import com.swmansion.enriched.markdown.styles.TextAlignment

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

/**
 * Maps Compose's [TextAlign] onto the alignment the text layer understands.
 *
 * [TextAlign.Unspecified] maps to `null`, leaving the value untouched.
 */
internal fun TextAlign.toStyleTextAlignment(): TextAlignment? =
  when (this) {
    TextAlign.Start -> TextAlignment.START
    TextAlign.Left -> TextAlignment.LEFT
    TextAlign.Center -> TextAlignment.CENTER
    TextAlign.End -> TextAlignment.END
    TextAlign.Right -> TextAlignment.RIGHT
    TextAlign.Justify -> TextAlignment.JUSTIFY
    else -> null
  }

/**
 * Maps Compose's [Alignment.Horizontal] onto the placement the table renderer understands.
 *
 * [Alignment.Start] and [Alignment.End] follow the reading direction; [AbsoluteAlignment] pins a
 * side. A custom horizontal alignment has no equivalent and falls back to the reading direction.
 */
internal fun Alignment.Horizontal.toStyleTableAlignment(): TableAlignment =
  when (this) {
    Alignment.Start -> TableAlignment.AUTO
    Alignment.CenterHorizontally -> TableAlignment.CENTER
    Alignment.End -> TableAlignment.END
    AbsoluteAlignment.Left -> TableAlignment.LEFT
    AbsoluteAlignment.Right -> TableAlignment.RIGHT
    else -> TableAlignment.AUTO
  }
