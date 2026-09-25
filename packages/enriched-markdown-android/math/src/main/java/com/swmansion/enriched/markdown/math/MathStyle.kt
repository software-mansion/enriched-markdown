package com.swmansion.enriched.markdown.math

import android.content.Context
import android.graphics.Color
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.StyleExtensionKey
import com.swmansion.enriched.markdown.styles.StyleParser
import com.swmansion.enriched.markdown.styles.TextAlignment
import java.util.concurrent.ConcurrentHashMap

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
fun StyleConfig.mathStyle(context: Context): MathStyle = getOrDefault(MathStyleKey, MathStyleDefaults.of(context).math)

/** The style an `inlineMath { }` block resolved to, or the plugin's default when nothing set one. */
fun StyleConfig.inlineMathStyle(context: Context): InlineMathStyle =
  getOrDefault(InlineMathStyleKey, MathStyleDefaults.of(context).inlineMath)

/**
 * The plugin's own defaults. Core's `DefaultStyles` is internal to `:ui`, so a plugin carries its
 * own and core never has to know them.
 *
 * [mathStyle] takes its px conversions as functions because its two callers measure differently:
 * the view layer resolves against a [StyleParser], the Compose DSL against the composition's
 * density. One builder for both keeps the two from drifting apart.
 */
internal object MathDefaults {
  const val FONT_SIZE_SP = 20f
  const val PADDING_DP = 12f
  const val MARGIN_TOP_DP = 0f
  const val MARGIN_BOTTOM_DP = 16f
  const val COLOR_HEX = "#1F2937"
  const val BACKGROUND_COLOR_HEX = "#F3F4F6"
  val TEXT_ALIGN = TextAlignment.CENTER

  fun mathStyle(
    sp: (Float) -> Float,
    dp: (Float) -> Float,
  ): MathStyle =
    MathStyle(
      fontSize = sp(FONT_SIZE_SP),
      color = Color.parseColor(COLOR_HEX),
      backgroundColor = Color.parseColor(BACKGROUND_COLOR_HEX),
      padding = dp(PADDING_DP),
      marginTop = dp(MARGIN_TOP_DP),
      marginBottom = dp(MARGIN_BOTTOM_DP),
      textAlign = TEXT_ALIGN,
    )

  fun inlineMathStyle(): InlineMathStyle = InlineMathStyle(color = Color.parseColor(COLOR_HEX))
}

/**
 * The defaults resolved to px, cached per density rather than per render: an unstyled document
 * asks for them once per equation and once per inline span, on the scroll path.
 *
 * Everything a [StyleParser] reads is a function of the display metrics, so two contexts with the
 * same density and font scale resolve to the same values - which is what the key holds, instead of
 * the contexts themselves.
 */
private object MathStyleDefaults {
  private val cache = ConcurrentHashMap<DensityKey, Resolved>()

  fun of(context: Context): Resolved {
    val resources = context.resources
    val key = DensityKey(resources.displayMetrics.density, resources.configuration.fontScale)
    return cache.getOrPut(key) {
      val parser = StyleParser(context)
      Resolved(
        math = MathDefaults.mathStyle(parser::toPixelFromSP, parser::toPixelFromDIP),
        inlineMath = MathDefaults.inlineMathStyle(),
      )
    }
  }

  private data class DensityKey(
    val density: Float,
    val fontScale: Float,
  )

  class Resolved(
    val math: MathStyle,
    val inlineMath: InlineMathStyle,
  )
}
