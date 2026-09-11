package com.swmansion.enriched.markdown

import android.content.Context
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import androidx.annotation.VisibleForTesting
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.segments.ContainerNodeView
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.segments.SegmentViewCreators
import com.swmansion.enriched.markdown.segments.SegmentViewFactory
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListHitTestResult
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListTapUtils
import com.swmansion.enriched.markdown.utils.text.interaction.TaskListToggleUtils
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectionColors
import kotlin.math.max
import kotlin.math.min

class EnrichedMarkdown(
  context: Context,
) : ContainerNodeView(context) {
  private val parser = Parser.shared
  private val mainHandler = Handler(Looper.getMainLooper())

  @Volatile private var currentRenderId = 0L

  var markdownStyle: StyleConfig = StyleConfig.default(context)
    private set

  /**
   * The markdown last handed to [setMarkdownContent]. Setting the same string
   * again is a no-op, so checkbox toggles survive a caller that re-supplies
   * its unchanged source on every recomposition; a different string wins and
   * drops them.
   */
  private var baseMarkdown: String = ""

  /** Checked states set by checkbox taps since [baseMarkdown] was last set, keyed by task index. */
  private val taskListToggles = mutableMapOf<Int, Boolean>()

  /** The markdown this view renders: [baseMarkdown] with those toggles applied. */
  val currentMarkdown: String
    get() = TaskListToggleUtils.applyCheckedStates(baseMarkdown, taskListToggles)

  var md4cFlags: Md4cFlags = Md4cFlags.DEFAULT
    private set

  private var imageRequestHeaders: Map<String, String> = emptyMap()
  private var selectionColor: Int? = null
  private var selectionHandleColor: Int? = null
  private var isSelectable = true
  private var selectionMenuConfig = SelectionMenuConfig()
  private var enableTaskListItemToggle = true

  private var onLinkPressCallback: ((String) -> Unit)? = null
  private var onLinkLongPressCallback: ((String) -> Unit)? = null
  private var onTaskListItemPressCallback: ((TaskListItemPressEvent) -> Unit)? = null

  private var pendingSegments: List<RenderedSegment>? = null
  private var needsSegmentReset = false

  init {
    segmentViewFactory = RootFactory()
  }

  fun setMarkdownContent(markdown: String) {
    if (baseMarkdown == markdown) return
    baseMarkdown = markdown
    taskListToggles.clear()
    scheduleRender()
  }

  fun setMarkdown(content: String) = setMarkdownContent(content)

  fun setMarkdownStyle(style: StyleConfig) {
    if (markdownStyle == style) return
    markdownStyle = style
    // The segment signature is derived from AST nodes only, so a style-only
    // change leaves it unchanged; without this the reconciler would reuse the
    // old, unrestyled views instead of rebuilding them.
    needsSegmentReset = true
    scheduleRenderIfNeeded()
  }

  /**
   * Sets HTTP headers attached to remote image requests, e.g. a `Referer`
   * required by CDN hotlink protection or an `Authorization` token.
   * Headers participate in image cache identity, so the same URL requested
   * with different headers is fetched and cached separately.
   */
  fun setImageRequestHeaders(headers: Map<String, String>) {
    if (imageRequestHeaders == headers) return
    imageRequestHeaders = headers
    needsSegmentReset = true
    scheduleRenderIfNeeded()
  }

  fun setMd4cFlags(flags: Md4cFlags) {
    if (md4cFlags == flags) return
    md4cFlags = flags
    scheduleRenderIfNeeded()
  }

  fun setOnLinkPressCallback(callback: ((String) -> Unit)?) {
    onLinkPressCallback = callback
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.onLinkPressCallback = callback
    }
  }

  fun setOnLinkLongPressCallback(callback: ((String) -> Unit)?) {
    onLinkLongPressCallback = callback
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.onLinkLongPressCallback = callback
    }
  }

  /** Called after a tap on a task-list checkbox has toggled the item. */
  fun setOnTaskListItemPressCallback(callback: ((TaskListItemPressEvent) -> Unit)?) {
    onTaskListItemPressCallback = callback
  }

  /**
   * Controls whether tapping a task-list checkbox toggles its checked state.
   * When `false` the tap is fully inert: no visual toggle and no
   * `onTaskListItemPress`. Defaults to `true`. Text selection and links are
   * unaffected.
   */
  fun setEnableTaskListItemToggle(enabled: Boolean) {
    if (enableTaskListItemToggle == enabled) return
    enableTaskListItemToggle = enabled
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.enableTaskListItemToggle = enabled
    }
  }

  fun setIsSelectable(selectable: Boolean) {
    if (isSelectable == selectable) return
    isSelectable = selectable
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.setIsSelectable(selectable)
    }
  }

  fun setSelectable(selectable: Boolean) = setIsSelectable(selectable)

  fun setOnLinkPressListener(listener: ((String) -> Unit)?) = setOnLinkPressCallback(listener)

  fun setOnLinkLongPressListener(listener: ((String) -> Unit)?) = setOnLinkLongPressCallback(listener)

  fun setOnTaskListItemPressListener(listener: ((TaskListItemPressEvent) -> Unit)?) = setOnTaskListItemPressCallback(listener)

  fun setSelectionColor(color: Int?) {
    if (selectionColor == color) return
    selectionColor = color
    applySelectionColorsToSegments()
  }

  fun setSelectionHandleColor(color: Int?) {
    if (selectionHandleColor == color) return
    selectionHandleColor = color
    applySelectionColorsToSegments()
  }

  fun setSelectionMenuConfig(config: SelectionMenuConfig) {
    if (selectionMenuConfig == config) return
    selectionMenuConfig = config
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.selectionMenuConfig = config
    }
  }

  private fun applySelectionColorsToSegments() {
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.applySelectionColors(selectionColor, selectionHandleColor)
    }
  }

  /**
   * Resets transient state when this view is recycled in a Compose [AndroidView] pool.
   */
  fun prepareForViewReuse() {
    ++currentRenderId
    setOnLinkPressCallback(null)
    setOnLinkLongPressCallback(null)
    setOnTaskListItemPressCallback(null)
    setEnableTaskListItemToggle(true)
    setMarkdownContent("")
    taskListToggles.clear()
    pendingSegments = null
    applySegments(emptyList(), reset = true)
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    scheduleRenderIfNeeded()
  }

  private fun scheduleRenderIfNeeded() {
    if (baseMarkdown.isNotEmpty()) {
      scheduleRender()
    }
  }

  private fun scheduleRender() {
    val style = markdownStyle
    val markdown = currentMarkdown
    if (markdown.isEmpty()) return

    val renderId = ++currentRenderId

    MarkdownRenderDispatcher.submit(
      owner = this,
      priority = if (isAttachedToWindow) 1 else 0,
      isCancelled = { renderId != currentRenderId },
    ) {
      if (renderId != currentRenderId) return@submit

      try {
        val ast =
          parser.parseMarkdown(markdown, md4cFlags) ?: run {
            mainHandler.post { if (renderId == currentRenderId) landRenderedSegments(emptyList()) }
            return@submit
          }

        if (renderId != currentRenderId) return@submit

        val segments = splitASTIntoSegments(ast)
        val renderedSegments =
          MarkdownSegmentRenderer.render(
            segments,
            style,
            context,
            imageRequestHeaders,
            onLinkPressCallback,
            onLinkLongPressCallback,
          )

        if (renderId != currentRenderId) return@submit

        mainHandler.post { if (renderId == currentRenderId) landRenderedSegments(renderedSegments) }
      } catch (e: Exception) {
        Log.e(TAG, "Render failed: ${e.message}", e)
        mainHandler.post { if (renderId == currentRenderId) landRenderedSegments(emptyList()) }
      }
    }
  }

  private fun landRenderedSegments(renderedSegments: List<RenderedSegment>) {
    if (isAttachedToWindow) {
      applyRenderedSegments(renderedSegments)
    } else {
      pendingSegments = renderedSegments
    }
  }

  @VisibleForTesting
  internal fun applyRenderedSegments(renderedSegments: List<RenderedSegment>) {
    val reset = needsSegmentReset
    needsSegmentReset = false
    val topologyChanged = applySegments(renderedSegments, reset)

    if (width > 0) {
      val heightBefore = computeSegmentsTotalHeight()
      layoutSegments()
      val heightAfter = computeSegmentsTotalHeight()
      if (topologyChanged || heightBefore != heightAfter) requestLayout()
    } else {
      requestLayout()
    }
  }

  override fun onAttachedToWindow() {
    super.onAttachedToWindow()
    pendingSegments?.let {
      pendingSegments = null
      applyRenderedSegments(it)
    }
  }

  override fun onMeasure(
    widthMeasureSpec: Int,
    heightMeasureSpec: Int,
  ) {
    val widthMode = MeasureSpec.getMode(widthMeasureSpec)
    val availableWidth = MeasureSpec.getSize(widthMeasureSpec)
    val width =
      if (widthMode == MeasureSpec.EXACTLY) {
        availableWidth
      } else {
        // wrap_content: children decide the width, capped by the parent's bound when it has one.
        val childWidthSpec = MeasureSpec.makeMeasureSpec(availableWidth, MeasureSpec.AT_MOST)
        val childHeightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
        var desired = 0
        segmentViews.forEach { child ->
          child.measure(childWidthSpec, childHeightSpec)
          desired = max(desired, child.measuredWidth)
        }
        if (widthMode == MeasureSpec.AT_MOST) min(desired, availableWidth) else desired
      }

    measureSegmentChildren(width)
    setMeasuredDimension(width, resolveSize(computeSegmentsTotalHeight(), heightMeasureSpec))
  }

  override fun onLayout(
    changed: Boolean,
    l: Int,
    t: Int,
    r: Int,
    b: Int,
  ) {
    layoutSegments()
  }

  /**
   * Flips the tapped item's checkbox and its checked-text decoration, then
   * reports the new state. The toggle is view-local — the markdown handed to
   * [setMarkdownContent] is never mutated — so persist it from the callback
   * if it has to survive a new source string.
   */
  private fun toggleTaskListItem(
    view: EnrichedMarkdownInternalText,
    hit: TaskListHitTestResult,
  ) {
    val newChecked = !hit.checked
    taskListToggles[hit.taskIndex] = newChecked

    val toggledInPlace =
      TaskListTapUtils.updateTaskListItemCheckedState(view, hit.span, newChecked, markdownStyle)
    if (toggledInPlace) {
      view.accessibilityHelper.invalidateAccessibilityItems()
    } else {
      // The span is gone, taken by a render that landed mid-gesture. Re-render
      // instead, from a source that now carries the toggle.
      scheduleRender()
    }

    onTaskListItemPressCallback?.invoke(
      TaskListItemPressEvent(index = hit.taskIndex, checked = newChecked, text = hit.itemText),
    )
  }

  private fun segmentViewConfig(): SegmentViewConfig =
    SegmentViewConfig(
      context = context,
      style = markdownStyle,
      selectable = isSelectable,
      selectionColor = selectionColor,
      selectionHandleColor = selectionHandleColor,
      selectionMenuConfig = selectionMenuConfig,
      enableTaskListItemToggle = enableTaskListItemToggle,
      onTaskListItemTap = ::toggleTaskListItem,
    )

  private inner class RootFactory : SegmentViewFactory {
    override fun matchesKind(
      view: View,
      segment: RenderedSegment,
    ): Boolean =
      when (segment) {
        is RenderedSegment.Text -> view is EnrichedMarkdownInternalText
      }

    override fun createView(segment: RenderedSegment): View =
      when (segment) {
        is RenderedSegment.Text -> {
          SegmentViewCreators.createTextView(segment, segmentViewConfig()).apply {
            onLinkPressCallback = this@EnrichedMarkdown.onLinkPressCallback
            onLinkLongPressCallback = this@EnrichedMarkdown.onLinkLongPressCallback
          }
        }
      }

    override fun updateView(
      view: View,
      segment: RenderedSegment,
    ) {
      when (segment) {
        is RenderedSegment.Text -> SegmentViewCreators.updateTextView(view as EnrichedMarkdownInternalText, segment)
      }
    }
  }

  companion object {
    private const val TAG = "EnrichedMarkdown"
  }
}
