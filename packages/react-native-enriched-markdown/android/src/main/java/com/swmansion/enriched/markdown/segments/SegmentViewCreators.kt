package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.os.Build
import android.text.Layout
import android.util.Log
import android.util.TypedValue
import android.view.View
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.BreakStrategyUtils
import com.swmansion.enriched.markdown.utils.common.FeatureFlags
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectionColors

/**
 * Configuration shared by every ContainerNodeView's SegmentViewFactory so that
 * Text / Table / Math / CodeBlock / Blockquote child views are constructed the
 * same way regardless of the host (root document or nested blockquote).
 *
 * The root supplies the full wiring; a nested blockquote supplies the subset it
 * needs (styling, link/copy callbacks, accessibility labels) and treats
 * streaming as static.
 */
data class SegmentViewConfig(
  val context: Context,
  val style: StyleConfig,
  val allowFontScaling: Boolean,
  val maxFontSizeMultiplier: Float,
  val accessibilityLabels: AccessibilityLabels,
  val selectionMenuConfig: SelectionMenuConfig,
  val textBreakStrategy: String,
  val selectable: Boolean,
  val selectionColor: Int?,
  val selectionHandleColor: Int?,
  val contextMenuItemTexts: List<String>,
  val enableBlockContextMenu: Boolean,
  val onLinkPress: ((String) -> Unit)?,
  val onLinkLongPress: ((String) -> Unit)?,
  val onCopyPress: ((code: String, language: String) -> Unit)?,
  val onTaskListItemPress: ((taskIndex: Int, checked: Boolean, itemText: String) -> Unit)?,
  val onContextMenuItemPress: ((itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit)?,
)

/**
 * Pure per-kind child view creators used by both the root and nested factories.
 * Kept free of host-only concerns (streaming tail animation, pending fence
 * handling, spoiler overlay mode, task-list toggle) so the root can add those on
 * top while nested blockquotes reuse the exact same construction.
 */
object SegmentViewCreators {
  private const val TAG = "SegmentViewCreators"

  fun createTextView(
    segment: RenderedSegment.Text,
    config: SegmentViewConfig,
  ): EnrichedMarkdownInternalText =
    EnrichedMarkdownInternalText(config.context).apply {
      selectionMenuConfig = config.selectionMenuConfig
      accessibilityLabels = config.accessibilityLabels
      setIsSelectable(config.selectable)
      setTextSize(TypedValue.COMPLEX_UNIT_PX, config.style.paragraphStyle.fontSize)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        breakStrategy = BreakStrategyUtils.resolveBreakStrategy(config.textBreakStrategy)
      }
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && segment.needsJustify) {
        justificationMode = Layout.JUSTIFICATION_MODE_INTER_WORD
      }
      lastElementMarginBottom = segment.lastElementMarginBottom
      applyStyledText(segment.styledText)
      segment.imageSpans.forEach { it.registerTextView(this) }

      onTaskListItemPressCallback = { taskIndex, checked, itemText ->
        config.onTaskListItemPress?.invoke(taskIndex, checked, itemText)
      }

      if (config.contextMenuItemTexts.isNotEmpty()) {
        val onPress = config.onContextMenuItemPress
        if (onPress != null) {
          setContextMenuItems(config.contextMenuItemTexts) { itemText, selectedText, start, end ->
            onPress(itemText, selectedText, start, end)
          }
        }
      }

      applySelectionColors(config.selectionColor, config.selectionHandleColor)
    }

  fun updateTextView(
    view: EnrichedMarkdownInternalText,
    segment: RenderedSegment.Text,
  ) {
    view.lastElementMarginBottom = segment.lastElementMarginBottom
    view.applyStyledText(segment.styledText)
    segment.imageSpans.forEach { it.registerTextView(view) }
  }

  fun createTableView(
    segment: RenderedSegment.Table,
    config: SegmentViewConfig,
  ) = TableContainerView(config.context, config.style).apply {
    enableBlockContextMenu = config.enableBlockContextMenu
    allowFontScaling = config.allowFontScaling
    maxFontSizeMultiplier = config.maxFontSizeMultiplier
    accessibilityLabels = config.accessibilityLabels
    onLinkPress = config.onLinkPress
    onLinkLongPress = config.onLinkLongPress
    copyLabel = config.selectionMenuConfig.copyLabel
    copyAsMarkdownLabel = config.selectionMenuConfig.copyAsMarkdownLabel
    applyTableNode(segment.node)
  }

  fun createCodeBlockView(
    segment: RenderedSegment.CodeBlock,
    config: SegmentViewConfig,
  ) = CodeBlockContainerView(config.context, config.style).apply {
    enableBlockContextMenu = config.enableBlockContextMenu
    copyLabel = config.selectionMenuConfig.copyLabel
    copyAsMarkdownLabel = config.selectionMenuConfig.copyAsMarkdownLabel
    onCopyPress = { code, language -> config.onCopyPress?.invoke(code, language) }
    applyCodeBlockNode(segment.node)
  }

  // Availability is fixed at build time (the math source set is compiled in or not), so the
  // reflective lookup - including the ClassNotFoundException when math is disabled - is resolved
  // once instead of on every reconcile via isMathContainerView/matchesKind.
  private val cachedMathContainerClass: Class<*>? by lazy {
    try {
      Class.forName("com.swmansion.enriched.markdown.segments.MathContainerView")
    } catch (_: Exception) {
      null
    }
  }

  fun mathContainerClass(): Class<*>? = cachedMathContainerClass

  fun isMathContainerView(view: View): Boolean = cachedMathContainerClass?.isInstance(view) == true

  fun createMathView(
    segment: RenderedSegment.Math,
    config: SegmentViewConfig,
  ): View {
    val resolvedClass = mathContainerClass()
    if (!FeatureFlags.IS_MATH_ENABLED || resolvedClass == null) return View(config.context)
    return try {
      val view =
        resolvedClass
          .getConstructor(Context::class.java, StyleConfig::class.java)
          .newInstance(config.context, config.style) as View
      runCatching {
        resolvedClass
          .getMethod("setAccessibilityLabels", AccessibilityLabels::class.java)
          .invoke(view, config.accessibilityLabels)
      }
      resolvedClass
        .getMethod("setCopyLabel", String::class.java)
        .invoke(view, config.selectionMenuConfig.copyLabel)
      resolvedClass
        .getMethod("setCopyAsMarkdownLabel", String::class.java)
        .invoke(view, config.selectionMenuConfig.copyAsMarkdownLabel)
      resolvedClass
        .getMethod("setEnableBlockContextMenu", Boolean::class.javaPrimitiveType)
        .invoke(view, config.enableBlockContextMenu)
      resolvedClass.getMethod("applyLatex", String::class.java).invoke(view, segment.latex)
      view
    } catch (e: Exception) {
      Log.e(TAG, "Failed to create math view", e)
      View(config.context)
    }
  }

  fun updateMathView(
    view: View,
    segment: RenderedSegment.Math,
  ) {
    mathContainerClass()
      ?.getMethod("applyLatex", String::class.java)
      ?.invoke(view, segment.latex)
  }

  fun createBlockquoteView(
    segment: RenderedSegment.Blockquote,
    config: SegmentViewConfig,
  ) = BlockquoteContainerView(config.context, config).apply {
    applyBlockquoteNode(segment.node)
  }
}
