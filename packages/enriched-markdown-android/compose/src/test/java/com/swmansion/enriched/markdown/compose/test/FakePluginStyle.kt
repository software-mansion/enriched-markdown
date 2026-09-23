@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.compose.test

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.MarkdownStyleBuilder
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.PluginStylePatch
import com.swmansion.enriched.markdown.compose.style.PluginStyleScope
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.styles.StyleExtensionKey

/**
 * Stands in for a plugin's own style type, which lives outside this module: px and ARGB, exactly
 * like the styles core stores in `StyleConfig`.
 */
internal data class FakePluginStyle(
  val fontSize: Float,
  val color: Int,
  val padding: Float,
) {
  companion object {
    val DEFAULT_FONT_SIZE = 16.sp
    val DEFAULT_COLOR = Color(0xFF445566)
    val DEFAULT_PADDING = 4.dp

    /** The plugin's own default, converted through the scope it is resolved with. */
    fun default(scope: PluginStyleScope): FakePluginStyle =
      FakePluginStyle(
        fontSize = scope.px(DEFAULT_FONT_SIZE),
        color = scope.argb(DEFAULT_COLOR),
        padding = scope.px(DEFAULT_PADDING),
      )
  }
}

internal val FakePluginStyleKey = StyleExtensionKey<FakePluginStyle>("fake-plugin")

/** A second key, to check that a layer touching one plugin leaves another plugin's value alone. */
internal val OtherFakePluginStyleKey = StyleExtensionKey<FakePluginStyle>("other-fake-plugin")

internal data class FakePluginStylePatch(
  val fontSize: TextUnit? = null,
  val color: Color? = null,
  val padding: Dp? = null,
) : PluginStylePatch<FakePluginStyle> {
  override fun apply(
    base: FakePluginStyle?,
    scope: PluginStyleScope,
  ): FakePluginStyle {
    val current = base ?: FakePluginStyle.default(scope)
    return current.copy(
      fontSize = fontSize?.let { scope.px(it) } ?: current.fontSize,
      color = color?.let { scope.argb(it) } ?: current.color,
      padding = padding?.let { scope.px(it) } ?: current.padding,
    )
  }
}

@MarkdownStyleDsl
internal class FakePluginStyleScope(
  existing: FakePluginStylePatch?,
) {
  var fontSize: TextUnit? = existing?.fontSize
  var color: Color? = existing?.color
  var padding: Dp? = existing?.padding

  fun toPatch(): FakePluginStylePatch =
    FakePluginStylePatch(
      fontSize = fontSize,
      color = color,
      padding = padding,
    )
}

/** The DSL block a plugin ships as an extension function on the core builder. */
internal fun MarkdownStyleBuilder.fakePlugin(
  key: StyleExtensionKey<FakePluginStyle> = FakePluginStyleKey,
  block: FakePluginStyleScope.() -> Unit,
) = updatePluginPatch(key) { existing: FakePluginStylePatch? ->
  FakePluginStyleScope(existing).apply(block).toPatch()
}
