package com.swmansion.enriched.markdown.compose.style

import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import com.swmansion.enriched.markdown.plugin.InternalPluginApi

/**
 * The conversions a plugin's patch needs to turn Compose units into the px and ARGB values
 * [com.swmansion.enriched.markdown.styles.StyleConfig] stores. Mirrors core's own `StyleUnits`,
 * which stays internal.
 *
 * [context] is available for defaults that have to read resources or theme attributes.
 */
@InternalPluginApi
class PluginStyleScope internal constructor(
  val context: Context,
  private val units: StyleUnits,
) {
  /** Density-independent pixels to px, at the density the style is being resolved for. */
  fun px(value: Dp): Float = units.dp(value)

  /** Scale-independent pixels to px. Only `sp` is accepted, exactly as for core's own styles. */
  fun px(value: TextUnit): Float = units.sp(value)

  fun argb(value: Color): Int = units.color(value)
}

/**
 * A plugin's pending edits for one [com.swmansion.enriched.markdown.styles.StyleExtensionKey],
 * applied when the style is resolved.
 *
 * [base] is what the previous layer left for this key, or null when nothing has set it yet - the
 * patch supplies the plugin's own default in that case, so core never has to know it.
 *
 * Deliberately not a `fun interface`: style layers are compared with `equals` to decide whether
 * Compose has to recompose, and a lambda is never equal to an identically written one, which
 * would make every frame look like a style change. Implement this with a data class whose
 * properties are the pending edits.
 */
@InternalPluginApi
interface PluginStylePatch<S : Any> {
  fun apply(
    base: S?,
    scope: PluginStyleScope,
  ): S
}
