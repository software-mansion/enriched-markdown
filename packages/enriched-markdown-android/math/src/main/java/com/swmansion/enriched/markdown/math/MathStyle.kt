package com.swmansion.enriched.markdown.math

import android.content.Context
import android.graphics.Color
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleExtensionKey
import com.swmansion.enriched.markdown.styles.StyleParser
import com.swmansion.enriched.markdown.styles.TextAlignment

/**
 * Block math (`$$...$$`), in the units [StyleConfig] stores everywhere: lengths in px, colors as
 * ARGB. [textAlign] positions the equation inside the segment; the equation itself scrolls
 * horizontally when it is wider than the view.
 */
data class MathStyle(
  val fontSize: Float,
  val color: Int,
  val backgroundColor: Int,
  val padding: Float,
  val marginTop: Float,
  val marginBottom: Float,
  val textAlign: TextAlignment,
)

/**
 * Inline math (`$...$`). It draws inside the enclosing block's line, taking that block's font
 * size, so its color is the only thing left to own.
 */
data class InlineMathStyle(
  val color: Int,
)

/** The handle [MathStyle] is stored under in [StyleConfig.extensions]. */
val MathStyleKey: StyleExtensionKey<MathStyle> = StyleExtensionKey("com.swmansion.enriched.markdown.math:math")

/** The handle [InlineMathStyle] is stored under in [StyleConfig.extensions]. */
val InlineMathStyleKey: StyleExtensionKey<InlineMathStyle> =
  StyleExtensionKey("com.swmansion.enriched.markdown.math:inlineMath")

/** The style a `math { }` block resolved to, or the plugin's default when nothing set one. */
fun StyleConfig.mathStyle(context: Context): MathStyle = get(MathStyleKey) ?: MathDefaults.mathStyle(context)

/** The style an `inlineMath { }` block resolved to, or the plugin's default when nothing set one. */
fun StyleConfig.inlineMathStyle(): InlineMathStyle = get(InlineMathStyleKey) ?: MathDefaults.inlineMathStyle()

/**
 * The plugin's own defaults, resolved against a [Context] exactly as core's `DefaultStyles` is -
 * which is internal to `:ui`, so a plugin carries its own and core never has to know them. The
 * Compose DSL starts from these too, as core's DSL starts from `StyleConfig.default`.
 */
internal object MathDefaults {
  private const val FONT_SIZE_SP = 20f
  private const val PADDING_DP = 12f
  private const val MARGIN_TOP_DP = 0f
  private const val MARGIN_BOTTOM_DP = 16f
  private const val COLOR_HEX = "#1F2937"
  private const val BACKGROUND_COLOR_HEX = "#F3F4F6"

  fun mathStyle(context: Context): MathStyle {
    val parser = StyleParser(context)
    return MathStyle(
      fontSize = parser.toPixelFromSP(FONT_SIZE_SP),
      color = parser.color(COLOR_HEX),
      backgroundColor = parser.color(BACKGROUND_COLOR_HEX),
      padding = parser.toPixelFromDIP(PADDING_DP),
      marginTop = parser.toPixelFromDIP(MARGIN_TOP_DP),
      marginBottom = parser.toPixelFromDIP(MARGIN_BOTTOM_DP),
      textAlign = TextAlignment.CENTER,
    )
  }

  fun inlineMathStyle(): InlineMathStyle = InlineMathStyle(color = Color.parseColor(COLOR_HEX))
}
