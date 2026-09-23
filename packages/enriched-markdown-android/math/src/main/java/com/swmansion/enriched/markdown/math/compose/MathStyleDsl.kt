@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.math.compose

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.MarkdownStyleBuilder
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.PluginStylePatch
import com.swmansion.enriched.markdown.compose.style.PluginStyleScope
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
  val textAlign: TextAlignment? = null,
) : PluginStylePatch<MathStyle> {
  override fun apply(
    base: MathStyle?,
    scope: PluginStyleScope,
  ): MathStyle {
    val current = base ?: MathDefaults.mathStyle({ scope.px(it.sp) }, { scope.px(it.dp) })
    return current.copy(
      fontSize = fontSize?.let { scope.px(it) } ?: current.fontSize,
      color = color?.let { scope.argb(it) } ?: current.color,
      backgroundColor = backgroundColor?.let { scope.argb(it) } ?: current.backgroundColor,
      padding = padding?.let { scope.px(it) } ?: current.padding,
      marginTop = marginTop?.let { scope.px(it) } ?: current.marginTop,
      marginBottom = marginBottom?.let { scope.px(it) } ?: current.marginBottom,
      textAlign = textAlign ?: current.textAlign,
    )
  }
}

/** Block math (`$$...$$`). [textAlign] positions the equation: `LEFT`, `CENTER` (default) or `RIGHT`. */
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
  var textAlign: TextAlignment? = existing?.textAlign

  internal fun toPatch(): MathStylePatch =
    MathStylePatch(
      fontSize = fontSize,
      color = color,
      backgroundColor = backgroundColor,
      padding = padding,
      marginTop = marginTop,
      marginBottom = marginBottom,
      textAlign = textAlign,
    )
}

/** Pending edits to [InlineMathStyle]. */
@Immutable
internal data class InlineMathStylePatch(
  val color: Color? = null,
) : PluginStylePatch<InlineMathStyle> {
  override fun apply(
    base: InlineMathStyle?,
    scope: PluginStyleScope,
  ): InlineMathStyle {
    val current = base ?: MathDefaults.inlineMathStyle()
    return current.copy(color = color?.let { scope.argb(it) } ?: current.color)
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
 *   math { textAlign = TextAlignment.LEFT }
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
