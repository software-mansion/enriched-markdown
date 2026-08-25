package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.viewinterop.AndroidView
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.styles.StyleConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.swmansion.enriched.markdown.EnrichedMarkdownText as NativeMarkdownTextView

/**
 * Renders [markdown] using the native markdown TextView inside Compose.
 *
 * Style defaults come from the nearest [MarkdownTheme]. Override per instance via the [style]
 * parameter, or nest [MarkdownTheme] to scope styles to a subtree.
 *
 * **Previews:** This component renders nothing in `@Preview` because it relies on [AndroidView].
 */
@Composable
fun EnrichedMarkdownText(
  markdown: String,
  modifier: Modifier = Modifier,
  style: MarkdownStyle = MarkdownTheme.style,
  selectable: Boolean = true,
  imageRequestHeaders: Map<String, String> = emptyMap(),
  onLinkPress: ((String) -> Unit)? = null,
  onLinkLongPress: ((String) -> Unit)? = null,
) {
  val context = LocalContext.current
  val configuration = LocalConfiguration.current
  val density = LocalDensity.current
  val fontFamilyResolver = LocalFontFamilyResolver.current
  val defaultStyle = remember(context) { StyleConfig.default(context) }
  val styleConfig by produceState(defaultStyle, style, configuration, density, fontFamilyResolver) {
    val resolveContext =
      StyleResolveContext(
        context = context,
        density = density,
        fontFamilyResolver = fontFamilyResolver,
      )
    value =
      withContext(Dispatchers.Default) {
        style.resolve(resolveContext)
      }
  }

  val onLinkPressState by rememberUpdatedState(onLinkPress)
  val onLinkLongPressState by rememberUpdatedState(onLinkLongPress)

  AndroidView(
    modifier = modifier,
    factory = { viewContext ->
      NativeMarkdownTextView(viewContext).apply {
        setOnLinkPressCallback { url -> onLinkPressState?.invoke(url) }
        setOnLinkLongPressCallback { url -> onLinkLongPressState?.invoke(url) }
        setMarkdownStyle(styleConfig)
        setIsSelectable(selectable)
        setImageRequestHeaders(imageRequestHeaders)
        setMarkdownContent(markdown)
      }
    },
    update = { view ->
      view.setOnLinkPressCallback { url -> onLinkPressState?.invoke(url) }
      view.setOnLinkLongPressCallback { url -> onLinkLongPressState?.invoke(url) }
      view.setMarkdownStyle(styleConfig)
      view.setIsSelectable(selectable)
      view.setImageRequestHeaders(imageRequestHeaders)
      view.setMarkdownContent(markdown)
    },
    onReset = { view -> view.prepareForViewReuse() },
    onRelease = { view ->
      view.prepareForViewReuse()
    },
  )
}
