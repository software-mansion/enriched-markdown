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
import com.swmansion.enriched.markdown.EnrichedMarkdown as NativeMarkdownView
import com.swmansion.enriched.markdown.TaskListItemToggle as TaskListItemToggleInternal
import com.swmansion.enriched.markdown.parser.Md4cFlags as Md4cFlagsInternal
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay as SpoilerOverlayInternal

typealias Md4cFlags = Md4cFlagsInternal

typealias TaskListItemToggle = TaskListItemToggleInternal

typealias SpoilerOverlay = SpoilerOverlayInternal

/**
 * Renders [markdown] using the native markdown TextView inside Compose.
 *
 * Style defaults come from the nearest [MarkdownTheme]. Override per instance via the [style]
 * parameter, or nest [MarkdownTheme] to scope styles to a subtree.
 *
 * [flags] selects the optional md4c syntax extensions.
 *
 * [spoilerOverlay] picks how `||spoiler||` text is concealed until it is tapped.
 *
 * **Previews:** This component renders nothing in `@Preview` because it relies on [AndroidView].
 */
@Composable
fun EnrichedMarkdownText(
  markdown: String,
  modifier: Modifier = Modifier,
  style: MarkdownStyle = MarkdownTheme.style,
  flags: Md4cFlags = Md4cFlags.Default,
  selectable: Boolean = true,
  imageRequestHeaders: Map<String, String> = emptyMap(),
  onLinkClick: (String) -> Unit = {},
  onLinkLongClick: (String) -> Unit = {},
  onTaskListItemToggle: (TaskListItemToggle) -> Unit = {},
  taskListToggleEnabled: Boolean = true,
  spoilerOverlay: SpoilerOverlay = SpoilerOverlay.Particles,
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

  val onLinkClickState by rememberUpdatedState(onLinkClick)
  val onLinkLongClickState by rememberUpdatedState(onLinkLongClick)
  val onTaskListItemToggleState by rememberUpdatedState(onTaskListItemToggle)

  AndroidView(
    modifier = modifier,
    factory = { viewContext ->
      NativeMarkdownView(viewContext).apply {
        setOnLinkPressCallback { url -> onLinkClickState(url) }
        setOnLinkLongPressCallback { url -> onLinkLongClickState(url) }
        setOnTaskListItemPressCallback { event -> onTaskListItemToggleState(event) }
        setEnableTaskListItemToggle(taskListToggleEnabled)
        setSpoilerOverlay(spoilerOverlay)
        setMarkdownStyle(styleConfig)
        setMd4cFlags(flags)
        setIsSelectable(selectable)
        setImageRequestHeaders(imageRequestHeaders)
        setMarkdownContent(markdown)
      }
    },
    update = { view ->
      view.setOnLinkPressCallback { url -> onLinkClickState(url) }
      view.setOnLinkLongPressCallback { url -> onLinkLongClickState(url) }
      view.setOnTaskListItemPressCallback { event -> onTaskListItemToggleState(event) }
      view.setEnableTaskListItemToggle(taskListToggleEnabled)
      view.setSpoilerOverlay(spoilerOverlay)
      view.setMarkdownStyle(styleConfig)
      view.setMd4cFlags(flags)
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
