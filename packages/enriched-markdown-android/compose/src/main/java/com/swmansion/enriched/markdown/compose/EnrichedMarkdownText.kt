package com.swmansion.enriched.markdown.compose

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalFontFamilyResolver
import androidx.compose.ui.viewinterop.AndroidView
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.CodeBlockCopy as CodeBlockCopyInternal
import com.swmansion.enriched.markdown.CodeBlockLayout as CodeBlockLayoutInternal
import com.swmansion.enriched.markdown.EnrichedMarkdown as NativeMarkdownView
import com.swmansion.enriched.markdown.MarkdownOptions as MarkdownOptionsInternal
import com.swmansion.enriched.markdown.TaskListItemToggle as TaskListItemToggleInternal
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin as MarkdownPluginInternal
import com.swmansion.enriched.markdown.plugin.PluginEvent as PluginEventInternal

typealias MarkdownOptions = MarkdownOptionsInternal

typealias CodeBlockLayout = CodeBlockLayoutInternal

typealias CodeBlockCopy = CodeBlockCopyInternal

typealias TaskListItemToggle = TaskListItemToggleInternal

typealias PluginEvent = PluginEventInternal

typealias MarkdownPlugin = MarkdownPluginInternal

/**
 * Renders [markdown] using the native markdown TextView inside Compose.
 *
 * Style defaults come from the nearest [MarkdownTheme]. Override per instance via the [style]
 * parameter, or nest [MarkdownTheme] to scope styles to a subtree.
 *
 * [options] selects the optional syntax extensions. Math is not one of them: enabling a math plugin
 * turns it on.
 *
 * [codeBlockLayout] set to [CodeBlockLayout.Scrollable] keeps long code lines intact and scrolls
 * them horizontally, for code blocks at the top level of the document. Those blocks leave the text
 * selection and copy with a long-press instead. Blocks inside a list item or a quote always wrap.
 *
 * [onCodeBlockCopy] is called after such a block's copy button or long-press Copy puts its code on
 * the clipboard, for example to show a "Copied" snackbar. Copy as Markdown does not call it.
 *
 * [spoilerOverlay] picks how `||spoiler||` text is concealed until it is tapped. The overlays are
 * rebuilt only when it changes by `==`, so pass a data class or object, or `remember` it.
 *
 * [includeLastBlockMargin] keeps the last block's bottom margin, so the view ends with the same
 * spacing that separates its blocks instead of flush with its last line. Turn it on when stacking
 * several of these one after another.
 *
 * [plugins] defaults to those enabled by the enclosing [MarkdownPlugins] scopes.
 *
 * [onPluginEvent] receives events reported by installed plugins (for example an expression a
 * plugin could not render), once per distinct event until [markdown] is replaced rather than
 * appended to.
 *
 * **Previews:** This component renders nothing in `@Preview` because it relies on [AndroidView].
 */
@Composable
fun EnrichedMarkdownText(
  markdown: String,
  modifier: Modifier = Modifier,
  style: MarkdownStyle = MarkdownTheme.style,
  options: MarkdownOptions = MarkdownOptions.Default,
  selectable: Boolean = true,
  codeBlockLayout: CodeBlockLayout = CodeBlockLayout.Wrapping,
  imageRequestHeaders: Map<String, String> = emptyMap(),
  onLinkClick: (String) -> Unit = {},
  onLinkLongClick: (String) -> Unit = {},
  onTaskListItemToggle: (TaskListItemToggle) -> Unit = {},
  onCodeBlockCopy: (CodeBlockCopy) -> Unit = {},
  taskListToggleEnabled: Boolean = true,
  spoilerOverlay: SpoilerOverlay = SpoilerOverlay.Particles(),
  includeLastBlockMargin: Boolean = false,
  plugins: List<MarkdownPlugin> = LocalMarkdownPlugins.current,
  onPluginEvent: (PluginEvent) -> Unit = {},
) {
  val context = LocalContext.current
  val configuration = LocalConfiguration.current
  val density = LocalDensity.current
  val fontFamilyResolver = LocalFontFamilyResolver.current
  val styleConfig =
    remember(style, configuration, context, density, fontFamilyResolver) {
      style.resolve(StyleResolveContext(context, density, fontFamilyResolver))
    }

  val onLinkClickState by rememberUpdatedState(onLinkClick)
  val onLinkLongClickState by rememberUpdatedState(onLinkLongClick)
  val onTaskListItemToggleState by rememberUpdatedState(onTaskListItemToggle)
  val onCodeBlockCopyState by rememberUpdatedState(onCodeBlockCopy)
  val onPluginEventState by rememberUpdatedState(onPluginEvent)

  AndroidView(
    modifier = modifier,
    factory = { viewContext ->
      NativeMarkdownView(viewContext).apply {
        setOnLinkPressCallback { url -> onLinkClickState(url) }
        setOnLinkLongPressCallback { url -> onLinkLongClickState(url) }
        setOnTaskListItemPressCallback { event -> onTaskListItemToggleState(event) }
        setOnCodeBlockCopyCallback { copy -> onCodeBlockCopyState(copy) }
        setOnPluginEventCallback { event -> onPluginEventState(event) }
        setEnableTaskListItemToggle(taskListToggleEnabled)
        setSpoilerOverlay(spoilerOverlay)
        setAllowTrailingMargin(includeLastBlockMargin)
        setPlugins(plugins)
        setMarkdownStyle(styleConfig)
        setOptions(options)
        setIsSelectable(selectable)
        setCodeBlockLayout(codeBlockLayout)
        setImageRequestHeaders(imageRequestHeaders)
        setMarkdownContent(markdown)
      }
    },
    update = { view ->
      view.setOnLinkPressCallback { url -> onLinkClickState(url) }
      view.setOnLinkLongPressCallback { url -> onLinkLongClickState(url) }
      view.setOnTaskListItemPressCallback { event -> onTaskListItemToggleState(event) }
      view.setOnCodeBlockCopyCallback { copy -> onCodeBlockCopyState(copy) }
      view.setOnPluginEventCallback { event -> onPluginEventState(event) }
      view.setEnableTaskListItemToggle(taskListToggleEnabled)
      view.setSpoilerOverlay(spoilerOverlay)
      view.setAllowTrailingMargin(includeLastBlockMargin)
      view.setPlugins(plugins)
      view.setMarkdownStyle(styleConfig)
      view.setOptions(options)
      view.setIsSelectable(selectable)
      view.setCodeBlockLayout(codeBlockLayout)
      view.setImageRequestHeaders(imageRequestHeaders)
      view.setMarkdownContent(markdown)
    },
    onReset = { view -> view.prepareForViewReuse() },
    onRelease = { view ->
      view.prepareForViewReuse()
    },
  )
}
