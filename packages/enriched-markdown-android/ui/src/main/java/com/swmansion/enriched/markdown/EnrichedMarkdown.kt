@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown

import android.content.Context
import android.content.res.Configuration
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import androidx.annotation.VisibleForTesting
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.plugin.EnrichedMarkdownPlugins
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginEvent
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.segments.ContainerNodeView
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.segments.SegmentViewCreators
import com.swmansion.enriched.markdown.segments.SegmentViewFactory
import com.swmansion.enriched.markdown.segments.TableContainerView
import com.swmansion.enriched.markdown.segments.splitASTIntoSegments
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
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

  var md4cFlags: Md4cFlags = Md4cFlags.Default
    private set

  /** How unrevealed `||spoiler||` text is concealed. */
  var spoilerOverlay: SpoilerOverlay = SpoilerOverlay.Particles()
    private set

  private var imageRequestHeaders: Map<String, String> = emptyMap()
  private var selectionColor: Int? = null
  private var selectionHandleColor: Int? = null
  private var isSelectable = true
  private var selectionMenuConfig = SelectionMenuConfig()
  private var enableTaskListItemToggle = true

  private var onLinkPressCallback: ((String) -> Unit)? = null
  private var onLinkLongPressCallback: ((String) -> Unit)? = null
  private var onTaskListItemPressCallback: ((TaskListItemToggle) -> Unit)? = null
  private var onPluginEventCallback: ((PluginEvent) -> Unit)? = null

  /** Events already reported, kept while the markdown only grows (streaming) and bounded in size. */
  private val reportedPluginEvents =
    object : LinkedHashMap<PluginEvent, Unit>() {
      override fun removeEldestEntry(eldest: MutableMap.MutableEntry<PluginEvent, Unit>?): Boolean = size > MAX_REPORTED_PLUGIN_EVENTS
    }

  /** Bumped with every clear of [reportedPluginEvents], so events from a superseded render are dropped. */
  private var pluginEventGeneration = 0

  private val pluginEventSink = PluginEventSink { event -> onMainThread { deliverPluginEvent(event) } }

  private var pendingSegments: List<RenderedSegment>? = null
  private var needsSegmentReset = false

  init {
    segmentViewFactory = RootFactory()
  }

  fun setMarkdownContent(markdown: String) {
    if (baseMarkdown == markdown) return
    // Streaming appends; anything else is a new document.
    if (!markdown.startsWith(baseMarkdown)) forgetReportedPluginEvents()
    baseMarkdown = markdown
    // A checkbox tap mutates the child's spannable in place, leaving the segment
    // signature on the pre-tap AST. Dropping those toggles here can therefore land
    // on an identical signature - a source that differs only outside the AST, say -
    // and the reconciler would keep showing the toggled state.
    if (taskListToggles.isNotEmpty()) needsSegmentReset = true
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
    segmentViews.filterIsInstance<TableContainerView>().forEach {
      it.onLinkPress = callback
    }
  }

  fun setOnLinkLongPressCallback(callback: ((String) -> Unit)?) {
    onLinkLongPressCallback = callback
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.onLinkLongPressCallback = callback
    }
    segmentViews.filterIsInstance<TableContainerView>().forEach {
      it.onLinkLongPress = callback
    }
  }

  /** Called after a tap on a task-list checkbox has toggled the item. */
  fun setOnTaskListItemPressCallback(callback: ((TaskListItemToggle) -> Unit)?) {
    onTaskListItemPressCallback = callback
  }

  /**
   * Called when a plugin reports an event for this view, e.g. a LaTeX expression that failed to
   * render and fell back to its raw source. Fires once per distinct event until the markdown is
   * replaced (rather than appended to) or the view is recycled via [prepareForViewReuse].
   */
  fun setOnPluginEventCallback(callback: ((PluginEvent) -> Unit)?) {
    onPluginEventCallback = callback
  }

  /** The sink for one render's events, which the render thread may post after the document it rendered is gone. */
  @VisibleForTesting
  internal fun renderPluginEventSink(): PluginEventSink {
    val generation = pluginEventGeneration
    return PluginEventSink { event ->
      onMainThread { if (generation == pluginEventGeneration) deliverPluginEvent(event) }
    }
  }

  // Plugins emit from the render thread (renderPayload, node renderers) and from the main
  // thread (their views), so everything is funnelled onto the main thread: the dedup set and
  // the callback then live on one thread and need no locking of their own.
  private fun onMainThread(block: () -> Unit) {
    if (Looper.myLooper() === mainHandler.looper) {
      block()
    } else {
      mainHandler.post(block)
    }
  }

  private fun deliverPluginEvent(event: PluginEvent) {
    if (reportedPluginEvents.put(event, Unit) == null) {
      onPluginEventCallback?.invoke(event)
    }
  }

  private fun forgetReportedPluginEvents() {
    reportedPluginEvents.clear()
    pluginEventGeneration++
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

  fun setAllowTrailingMargin(allow: Boolean) {
    if (trailingMarginEnabled == allow) return
    trailingMarginEnabled = allow
    // Only the container's height and child offsets depend on it, so the
    // rendered segments stay valid and a layout pass is enough.
    requestLayout()
  }

  /** Chooses the overlay that conceals unrevealed spoilers. */
  fun setSpoilerOverlay(overlay: SpoilerOverlay) {
    if (spoilerOverlay == overlay) return
    spoilerOverlay = overlay
    segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
      it.spoilerOverlay = overlay
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

  fun setOnTaskListItemPressListener(listener: ((TaskListItemToggle) -> Unit)?) = setOnTaskListItemPressCallback(listener)

  fun setOnPluginEventListener(listener: ((PluginEvent) -> Unit)?) = setOnPluginEventCallback(listener)

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
    segmentViews.filterIsInstance<TableContainerView>().forEach {
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
    setOnPluginEventCallback(null)
    setEnableTaskListItemToggle(true)
    setSpoilerOverlay(SpoilerOverlay.Particles())
    setAllowTrailingMargin(false)
    setMarkdownContent("")
    taskListToggles.clear()
    forgetReportedPluginEvents()
    pendingSegments = null
    applySegments(emptyList(), reset = true)
  }

  override fun onConfigurationChanged(newConfig: Configuration) {
    super.onConfigurationChanged(newConfig)
    // The AST, and so the signature, is unchanged by a configuration change, so
    // without this the reconciler would reuse the children and drop the re-render
    // along with the width-dependent state (image bounds) it carries.
    needsSegmentReset = true
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
    val plugins = EnrichedMarkdownPlugins.snapshot
    val onPluginEvent = renderPluginEventSink()

    warnIfMathPluginMissing(plugins)

    val renderId = ++currentRenderId
    // Segments rendered while detached are superseded by this render.
    pendingSegments = null

    if (markdown.isEmpty()) {
      landRenderedSegments(emptyList())
      return
    }

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

        val segments = splitASTIntoSegments(ast, plugins)
        val renderedSegments =
          MarkdownSegmentRenderer.render(
            segments,
            style,
            context,
            imageRequestHeaders,
            onPluginEvent = onPluginEvent,
            plugins = plugins,
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
        // An UNSPECIFIED parent carries no bound - its size is 0 - so children measure unbounded.
        val childWidthSpec =
          if (widthMode == MeasureSpec.UNSPECIFIED) {
            MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
          } else {
            MeasureSpec.makeMeasureSpec(availableWidth, MeasureSpec.AT_MOST)
          }
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
      TaskListItemToggle(index = hit.taskIndex, checked = newChecked, text = hit.itemText),
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
      spoilerOverlay = spoilerOverlay,
      onTaskListItemTap = ::toggleTaskListItem,
      onLinkPress = onLinkPressCallback,
      onLinkLongPress = onLinkLongPressCallback,
      onPluginEvent = pluginEventSink,
    )

  /**
   * Parsing latex without a plugin to render it is a dependency the app forgot, not a content
   * error, so it is reported once per process rather than per view or per render.
   */
  private fun warnIfMathPluginMissing(plugins: PluginSnapshot) {
    if (!md4cFlags.latexMath || missingMathPluginWarned) return
    if (MATH_NODE_TYPES.any { it in plugins.nodeRenderers || it in plugins.blockSegments }) return

    missingMathPluginWarned = true
    Log.w(
      TAG,
      "Md4cFlags(latexMath = true) but no plugin renders math, so equations show as their raw " +
        "source. Add the com.swmansion.enriched.markdown:math artifact and call " +
        "EnrichedMarkdownPlugins.install(LatexMathPlugin) at startup.",
    )
  }

  private inner class RootFactory : SegmentViewFactory {
    override fun matchesKind(
      view: View,
      segment: RenderedSegment,
    ): Boolean =
      when (segment) {
        is RenderedSegment.Text -> view is EnrichedMarkdownInternalText
        is RenderedSegment.Table -> view is TableContainerView
        is RenderedSegment.Custom<*> -> segment.matchesView(view)
      }

    override fun createView(segment: RenderedSegment): View =
      when (segment) {
        is RenderedSegment.Text -> SegmentViewCreators.createTextView(segment, segmentViewConfig())
        is RenderedSegment.Table -> SegmentViewCreators.createTableView(segment, segmentViewConfig())
        is RenderedSegment.Custom<*> -> segment.createView(segmentViewConfig())
      }

    override fun updateView(
      view: View,
      segment: RenderedSegment,
    ) {
      when (segment) {
        is RenderedSegment.Text -> SegmentViewCreators.updateTextView(view as EnrichedMarkdownInternalText, segment)
        is RenderedSegment.Table -> SegmentViewCreators.updateTableView(view as TableContainerView, segment, segmentViewConfig())
        is RenderedSegment.Custom<*> -> segment.updateView(view, segmentViewConfig())
      }
    }
  }

  companion object {
    private const val TAG = "EnrichedMarkdown"
    private const val MAX_REPORTED_PLUGIN_EVENTS = 256

    private val MATH_NODE_TYPES =
      listOf(MarkdownASTNode.NodeType.LatexMathInline, MarkdownASTNode.NodeType.LatexMathDisplay)

    @Volatile
    private var missingMathPluginWarned = false
  }
}
