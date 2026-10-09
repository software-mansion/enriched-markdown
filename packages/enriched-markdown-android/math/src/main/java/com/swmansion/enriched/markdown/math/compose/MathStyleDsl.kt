@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math.compose

import androidx.compose.runtime.Immutable
import androidx.compose.ui.AbsoluteAlignment
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.compose.MarkdownStyleBuilder
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.PluginStylePatch
import com.swmansion.enriched.markdown.compose.style.PluginStyleUnits
import com.swmansion.enriched.markdown.math.InlineMathStyle
import com.swmansion.enriched.markdown.math.InlineMathStyleKey
import com.swmansion.enriched.markdown.math.MathDefaults
import com.swmansion.enriched.markdown.math.MathStyle
import com.swmansion.enriched.markdown.math.MathStyleKey
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.styles.TextAlignment

/**
 * Pending edits to [MathStyle]. A data class, not a lambda: style layers are compared by equality
 * to decide whether Compose has to recompose.
 */
@Immutable
internal data class MathStylePatch(
  val fontSize: TextUnit? = null,
  val color: Color? = null,
  val backgroundColor: Color? = null,
  val padding: Dp? = null,
  val marginTop: Dp? = null,
  val marginBottom: Dp? = null,
  val alignment: Alignment.Horizontal? = null,
) : PluginStylePatch<MathStyle> {
  override fun apply(
    base: MathStyle?,
    units: PluginStyleUnits,
  ): MathStyle {
    val current = base ?: MathDefaults.mathStyle(units.context)
    return current.copy(
      fontSize = fontSize?.let { units.px(it) } ?: current.fontSize,
      color = color?.let { units.argb(it) } ?: current.color,
      backgroundColor = backgroundColor?.let { units.argb(it) } ?: current.backgroundColor,
      padding = padding?.let { units.px(it) } ?: current.padding,
      marginTop = marginTop?.let { units.px(it) } ?: current.marginTop,
      marginBottom = marginBottom?.let { units.px(it) } ?: current.marginBottom,
      textAlign = alignment?.toMathTextAlignment() ?: current.textAlign,
    )
  }
}

/**
 * Block math (`$$...$$`).
 *
 * [alignment] places the equation inside its block. It is an [Alignment.Horizontal], like the
 * table's, rather than a `TextAlign`: it positions the whole equation box, not lines of text, so
 * `Justify` would mean nothing. [Alignment.Start], [Alignment.CenterHorizontally] (the default) and
 * [Alignment.End] follow the reading direction; [AbsoluteAlignment.Left] and
 * [AbsoluteAlignment.Right] pin a side regardless of it.
 */
@MarkdownStyleDsl
class MathStyleScope internal constructor(
  existing: MathStylePatch?,
) {
  var fontSize: TextUnit? = existing?.fontSize
  var color: Color? = existing?.color
  var backgroundColor: Color? = existing?.backgroundColor
  var padding: Dp? = existing?.padding
  var marginTop: Dp? = existing?.marginTop
  var marginBottom: Dp? = existing?.marginBottom
  var alignment: Alignment.Horizontal? = existing?.alignment

  internal fun toPatch(): MathStylePatch =
    MathStylePatch(
      fontSize = fontSize,
      color = color,
      backgroundColor = backgroundColor,
      padding = padding,
      marginTop = marginTop,
      marginBottom = marginBottom,
      alignment = alignment,
    )
}

/** A custom horizontal alignment has no equivalent and falls back to the reading direction. */
private fun Alignment.Horizontal.toMathTextAlignment(): TextAlignment =
  when (this) {
    Alignment.Start -> TextAlignment.START
    Alignment.CenterHorizontally -> TextAlignment.CENTER
    Alignment.End -> TextAlignment.END
    AbsoluteAlignment.Left -> TextAlignment.LEFT
    AbsoluteAlignment.Right -> TextAlignment.RIGHT
    else -> TextAlignment.START
  }

/** Pending edits to [InlineMathStyle]. */
@Immutable
internal data class InlineMathStylePatch(
  val color: Color? = null,
) : PluginStylePatch<InlineMathStyle> {
  override fun apply(
    base: InlineMathStyle?,
    units: PluginStyleUnits,
  ): InlineMathStyle {
    val current = base ?: MathDefaults.inlineMathStyle()
    return current.copy(color = color?.let { units.argb(it) } ?: current.color)
  }
}

/** Inline math (`$...$`). It takes its font size from the block it sits in. */
@MarkdownStyleDsl
class InlineMathStyleScope internal constructor(
  existing: InlineMathStylePatch?,
) {
  var color: Color? = existing?.color

  internal fun toPatch(): InlineMathStylePatch = InlineMathStylePatch(color = color)
}

/**
 * Styles block math (`$$...$$`) from core's Compose style DSL:
 *
 * ```
 * markdownStyle {
 *   math { alignment = Alignment.Start }
 *   inlineMath { color = Color(0xFF7C3AED) }
 * }
 * ```
 *
 * Repeating the block merges into the earlier one rather than replacing it, and properties left
 * unset keep the plugin's own defaults.
 *
 * This is the only part of the plugin that touches `:compose`, which is why math depends on it at
 * compile time only: an app rendering through the View API never loads these.
 */
fun MarkdownStyleBuilder.math(block: MathStyleScope.() -> Unit) =
  updatePluginPatch(MathStyleKey) { existing: MathStylePatch? ->
    MathStyleScope(existing).apply(block).toPatch()
  }

/** Styles inline math. Merges across blocks exactly as [math] does. */
fun MarkdownStyleBuilder.inlineMath(block: InlineMathStyleScope.() -> Unit) =
  updatePluginPatch(InlineMathStyleKey) { existing: InlineMathStylePatch? ->
    InlineMathStyleScope(existing).apply(block).toPatch()
  }
