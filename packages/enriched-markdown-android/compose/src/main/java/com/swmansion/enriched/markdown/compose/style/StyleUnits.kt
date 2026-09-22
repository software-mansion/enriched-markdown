package com.swmansion.enriched.markdown.compose.style

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.calculateEndPadding
import androidx.compose.foundation.layout.calculateStartPadding
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
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

  /**
   * The native renderer draws a single inset on every side of a block, so only uniform
   * [PaddingValues] can be honoured. [property] names the DSL property in the error message.
   */
  fun padding(
    value: PaddingValues,
    property: String,
  ): Float {
    val start = value.calculateStartPadding(LayoutDirection.Ltr)
    val top = value.calculateTopPadding()
    val end = value.calculateEndPadding(LayoutDirection.Ltr)
    val bottom = value.calculateBottomPadding()
    require(start == top && start == end && start == bottom) {
      "$property must be uniform: the native renderer draws one inset on every side, " +
        "got start=$start, top=$top, end=$end, bottom=$bottom"
    }
    return dp(start)
  }
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
 * The layer aligns relative to the reading direction, so [TextAlign.Left] and [TextAlign.Right]
 * resolve the same way as [TextAlign.Start] and [TextAlign.End]. [TextAlign.Unspecified] leaves
 * the value untouched.
 */
internal fun TextAlign.toStyleTextAlignment(): TextAlignment =
  when (this) {
    TextAlign.Start, TextAlign.Left -> TextAlignment.LEFT
    TextAlign.Center -> TextAlignment.CENTER
    TextAlign.End, TextAlign.Right -> TextAlignment.RIGHT
    TextAlign.Justify -> TextAlignment.JUSTIFY
    else -> TextAlignment.AUTO
  }

/**
 * Maps Compose's [Alignment.Horizontal] onto the placement the table renderer understands.
 *
 * [Alignment.Start] follows the reading direction; [AbsoluteAlignment] pins a side. A custom
 * horizontal alignment has no equivalent and falls back to the reading direction.
 */
internal fun Alignment.Horizontal.toStyleTableAlignment(): TableAlignment =
  when (this) {
    Alignment.Start -> TableAlignment.AUTO
    Alignment.CenterHorizontally -> TableAlignment.CENTER
    Alignment.End -> TableAlignment.RIGHT
    AbsoluteAlignment.Left -> TableAlignment.LEFT
    AbsoluteAlignment.Right -> TableAlignment.RIGHT
    else -> TableAlignment.AUTO
  }

internal fun TableAlignment.toComposeAlignment(): Alignment.Horizontal =
  when (this) {
    TableAlignment.AUTO -> Alignment.Start
    TableAlignment.LEFT -> AbsoluteAlignment.Left
    TableAlignment.CENTER -> Alignment.CenterHorizontally
    TableAlignment.RIGHT -> AbsoluteAlignment.Right
  }
