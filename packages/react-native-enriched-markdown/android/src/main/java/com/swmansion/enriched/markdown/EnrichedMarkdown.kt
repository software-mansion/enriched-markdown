package com.swmansion.enriched.markdown

import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.AttributeSet
import android.util.Log
import android.view.View
import android.widget.FrameLayout
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.uimanager.StateWrapper
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.parser.Md4cFlags
import com.swmansion.enriched.markdown.parser.Parser
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.common.BreakStrategyUtils
import com.swmansion.enriched.markdown.utils.common.CodeBlockStreamingMode
import com.swmansion.enriched.markdown.utils.common.FeatureFlags
import com.swmansion.enriched.markdown.utils.common.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.utils.common.RenderedSegment
import com.swmansion.enriched.markdown.utils.common.SegmentReconciler
import com.swmansion.enriched.markdown.utils.common.StreamingMarkdownFilter
import com.swmansion.enriched.markdown.utils.common.TableStreamingMode
import com.swmansion.enriched.markdown.utils.common.isReducedMotionEnabled
import com.swmansion.enriched.markdown.utils.common.splitASTIntoSegments
import com.swmansion.enriched.markdown.utils.text.TailFadeInAnimator
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.utils.text.view.applySelectionColors
import com.swmansion.enriched.markdown.views.BlockSegmentView
import com.swmansion.enriched.markdown.views.CodeBlockContainerView
import com.swmansion.enriched.markdown.views.TableContainerView
import java.util.EnumSet
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.ceil
import kotlin.math.max

class EnrichedMarkdown
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : FrameLayout(context, attrs, defStyleAttr) {
    private enum class DirtyFlag {
      RECREATE_SEGMENTS,
      FORCE_HEIGHT,
    }

    private val parser = Parser.shared
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mathContainerClass: Class<*>? by lazy {
      try {
        Class.forName("com.swmansion.enriched.markdown.views.MathContainerView")
      } catch (_: Exception) {
        null
      }
    }

    private var currentRenderId = 0L
    private val segmentViews = mutableListOf<View>()
    private val segmentSignatures = mutableListOf<Long>()
    private val dirtyFlags = EnumSet.noneOf(DirtyFlag::class.java)
    var streamingAnimation: Boolean = false

    // used to force a Yoga re-measure when a block image resolves its box height
    var stateWrapper: StateWrapper? = null
    private var forceHeightRecalculationCounter = 0

    var tableStreamingMode: TableStreamingMode = TableStreamingMode.PROGRESSIVE
    var codeBlockStreamingMode: CodeBlockStreamingMode = CodeBlockStreamingMode.PROGRESSIVE
    private var renderPending: Boolean = false

    var currentMarkdown: String = ""
      private set

    var markdownStyle: StyleConfig? = null
      private set

    private var markdownStyleMap: ReadableMap? = null
    private var lastKnownFontScale: Float = context.resources.configuration.fontScale

    var md4cFlags: Md4cFlags = Md4cFlags.DEFAULT
      private set
    private var allowFontScaling: Boolean = true
    private var maxFontSizeMultiplier: Float = 0f
    private var allowTrailingMargin: Boolean = false
    private var imageRequestHeaders: Map<String, String> = emptyMap()
    private var selectable: Boolean = true
    private var selectionColor: Int? = null
    private var selectionHandleColor: Int? = null
    private var selectionMenuConfig = SelectionMenuConfig()
    private var accessibilityLabels = AccessibilityLabels()
    private var textBreakStrategy: String = BreakStrategyUtils.DEFAULT_STRATEGY

    private var onLinkPressCallback: ((String) -> Unit)? = null
    private var onLinkLongPressCallback: ((String) -> Unit)? = null
    private var onTaskListItemPressCallback: ((Int, Boolean, String) -> Unit)? = null
    private var onCopyPressCallback: ((String, String) -> Unit)? = null
    private var contextMenuItemTexts: List<String> = emptyList()
    var onContextMenuItemPressCallback: ((itemText: String, selectedText: String, selectionStart: Int, selectionEnd: Int) -> Unit)? = null
    var spoilerOverlay: SpoilerOverlay = SpoilerOverlay.PARTICLES
      set(value) {
        if (field == value) return
        field = value
        segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
          it.spoilerOverlay = value
        }
      }
    var enableTaskListItemToggle: Boolean = true
      set(value) {
        if (field == value) return
        field = value
        segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
          it.enableTaskListItemToggle = value
        }
      }

    fun setMarkdownContent(markdown: String) {
      if (currentMarkdown == markdown) return
      currentMarkdown = markdown
      renderPending = true
    }

    fun setMarkdownStyle(style: ReadableMap?) {
      markdownStyleMap = style
      val newConfig = style?.let { StyleConfig(it, context, allowFontScaling, maxFontSizeMultiplier) }
      newConfig?.imageRequestHeaders = imageRequestHeaders
      if (markdownStyle == newConfig) return
      markdownStyle = newConfig
      dirtyFlags += DirtyFlag.RECREATE_SEGMENTS
      dirtyFlags += DirtyFlag.FORCE_HEIGHT
      renderPending = true
    }

    fun setImageRequestHeaders(headers: Map<String, String>) {
      if (imageRequestHeaders == headers) return
      imageRequestHeaders = headers
      markdownStyle?.imageRequestHeaders = headers
      dirtyFlags += DirtyFlag.RECREATE_SEGMENTS
      renderPending = true
    }

    fun commitProps() {
      MeasurementStore.updateStreamingTableMode(id, tableStreamingMode)
      MeasurementStore.updateStreamingCodeBlockMode(id, codeBlockStreamingMode)
      MeasurementStore.updateFontScalingSettings(id, allowFontScaling, maxFontSizeMultiplier)
      if (renderPending) {
        renderPending = false
        scheduleRenderIfNeeded()
      }
    }

    override fun onConfigurationChanged(newConfig: Configuration) {
      super.onConfigurationChanged(newConfig)
      if (!allowFontScaling) return
      val newFontScale = newConfig.fontScale
      if (newFontScale != lastKnownFontScale) {
        lastKnownFontScale = newFontScale
        recreateStyleConfig()
        dirtyFlags += DirtyFlag.RECREATE_SEGMENTS
        dirtyFlags += DirtyFlag.FORCE_HEIGHT
        scheduleRenderIfNeeded()
      }
    }

    fun setMd4cFlags(flags: Md4cFlags) {
      if (md4cFlags == flags) return
      md4cFlags = flags
      renderPending = true
    }

    fun setAllowFontScaling(allow: Boolean) {
      if (allowFontScaling == allow) return
      allowFontScaling = allow
      MeasurementStore.updateFontScalingSettings(id, allowFontScaling, maxFontSizeMultiplier)
      recreateStyleConfig()
      dirtyFlags += DirtyFlag.RECREATE_SEGMENTS
      dirtyFlags += DirtyFlag.FORCE_HEIGHT
      renderPending = true
    }

    fun setMaxFontSizeMultiplier(multiplier: Float) {
      if (maxFontSizeMultiplier == multiplier) return
      maxFontSizeMultiplier = multiplier
      MeasurementStore.updateFontScalingSettings(id, allowFontScaling, maxFontSizeMultiplier)
      recreateStyleConfig()
      dirtyFlags += DirtyFlag.RECREATE_SEGMENTS
      dirtyFlags += DirtyFlag.FORCE_HEIGHT
      renderPending = true
    }

    fun setAllowTrailingMargin(allow: Boolean) {
      if (allowTrailingMargin == allow) return
      allowTrailingMargin = allow
      dirtyFlags += DirtyFlag.RECREATE_SEGMENTS
      dirtyFlags += DirtyFlag.FORCE_HEIGHT
      renderPending = true
    }

    fun setIsSelectable(value: Boolean) {
      if (selectable == value) return
      selectable = value
      segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
        it.setIsSelectable(value)
      }
    }

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

    fun setTextBreakStrategy(strategy: String) {
      if (textBreakStrategy == strategy) return
      textBreakStrategy = strategy
      MeasurementStore.updateBreakStrategy(id, strategy)
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
        val resolved = BreakStrategyUtils.resolveBreakStrategy(strategy)
        segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
          it.breakStrategy = resolved
        }
      }
      dirtyFlags += DirtyFlag.FORCE_HEIGHT
      renderPending = true
    }

    private fun applySelectionColorsToSegments() {
      segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
        it.applySelectionColors(selectionColor, selectionHandleColor)
      }
    }

    fun setOnLinkPressCallback(callback: (String) -> Unit) {
      onLinkPressCallback = callback
    }

    fun setOnLinkLongPressCallback(callback: (String) -> Unit) {
      onLinkLongPressCallback = callback
    }

    fun setOnTaskListItemPressCallback(callback: ((taskIndex: Int, checked: Boolean, itemText: String) -> Unit)?) {
      onTaskListItemPressCallback = callback
    }

    fun setOnCopyPressCallback(callback: ((code: String, language: String) -> Unit)?) {
      onCopyPressCallback = callback
    }

    fun setContextMenuItems(items: List<String>) {
      contextMenuItemTexts = items
      segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
        it.setContextMenuItems(items, ::forwardContextMenuItemPress)
      }
    }

    fun setSelectionMenuConfig(config: SelectionMenuConfig) {
      if (selectionMenuConfig == config) return
      selectionMenuConfig = config
      segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
        it.selectionMenuConfig = config
      }
      // Table and math views cache the copy labels, so re-push them on update
      // (e.g. a language change without a remount) to avoid stale labels.
      pushCopyLabelsToBlockSegments()
    }

    private fun pushCopyLabelsToBlockSegments() {
      val copyLabel = selectionMenuConfig.copyLabel
      val copyAsMarkdownLabel = selectionMenuConfig.copyAsMarkdownLabel
      segmentViews.forEach { view ->
        when {
          view is TableContainerView -> {
            view.copyLabel = copyLabel
            view.copyAsMarkdownLabel = copyAsMarkdownLabel
          }

          view is CodeBlockContainerView -> {
            view.copyLabel = copyLabel
            view.copyAsMarkdownLabel = copyAsMarkdownLabel
          }

          isMathContainerView(view) -> {
            runCatching {
              view.javaClass.getMethod("setCopyLabel", String::class.java).invoke(view, copyLabel)
              view.javaClass
                .getMethod("setCopyAsMarkdownLabel", String::class.java)
                .invoke(view, copyAsMarkdownLabel)
            }
          }
        }
      }
    }

    fun setAccessibilityLabels(labels: AccessibilityLabels) {
      if (accessibilityLabels == labels) return
      accessibilityLabels = labels
      segmentViews.filterIsInstance<EnrichedMarkdownInternalText>().forEach {
        it.accessibilityLabels = labels
      }
      segmentViews.filterIsInstance<TableContainerView>().forEach {
        it.accessibilityLabels = labels
      }
      mathContainerClass?.let { mathClass ->
        segmentViews.filter { mathClass.isInstance(it) }.forEach { view ->
          runCatching {
            mathClass
              .getMethod("setAccessibilityLabels", AccessibilityLabels::class.java)
              .invoke(view, labels)
          }
        }
      }
    }

    private fun forwardContextMenuItemPress(
      itemText: String,
      selectedText: String,
      selectionStart: Int,
      selectionEnd: Int,
    ) {
      onContextMenuItemPressCallback?.invoke(itemText, selectedText, selectionStart, selectionEnd)
    }

    private fun recreateStyleConfig() {
      markdownStyleMap?.let {
        markdownStyle =
          StyleConfig(it, context, allowFontScaling, maxFontSizeMultiplier).also { config ->
            config.imageRequestHeaders = imageRequestHeaders
          }
      }
    }

    private fun scheduleRenderIfNeeded() {
      if (currentMarkdown.isNotEmpty()) scheduleRender()
    }

    private fun scheduleRender() {
      val style = markdownStyle ?: return
      val markdown = currentMarkdown.takeIf { it.isNotEmpty() } ?: return
      val isStreaming = streamingAnimation
      val tableMode = tableStreamingMode
      val codeBlockMode = codeBlockStreamingMode

      val renderId = ++currentRenderId

      executor.execute {
        try {
          val filtered =
            if (isStreaming) {
              StreamingMarkdownFilter.renderableMarkdownForStreaming(markdown, tableMode, codeBlockMode)
            } else {
              null
            }
          val renderableMarkdown = filtered?.markdown ?: markdown
          val hasPendingCodeBlock = filtered?.endsInsideOpenCodeFence ?: false

          if (renderableMarkdown.isEmpty()) {
            postToMain(renderId) { applyRenderedSegments(emptyList(), style, false) }
            return@execute
          }

          val ast =
            parser.parseMarkdown(renderableMarkdown, md4cFlags) ?: run {
              postToMain(renderId) { applyRenderedSegments(emptyList(), style, false) }
              return@execute
            }

          val segments = splitASTIntoSegments(ast)
          val renderedSegments =
            MarkdownSegmentRenderer.render(
              segments,
              style,
              context,
              onLinkPressCallback,
              onLinkLongPressCallback,
            )

          postToMain(renderId) { applyRenderedSegments(renderedSegments, style, hasPendingCodeBlock) }
        } catch (e: Exception) {
          Log.e(TAG, "Render failed", e)
          postToMain(renderId) { applyRenderedSegments(emptyList(), style, false) }
        }
      }
    }

    // Trailing code block whose closing fence hasn't streamed in yet, if any.
    private var pendingCodeBlockSegment: RenderedSegment.CodeBlock? = null

    private fun applyRenderedSegments(
      renderedSegments: List<RenderedSegment>,
      style: StyleConfig,
      hasPendingCodeBlock: Boolean,
    ) {
      pendingCodeBlockSegment =
        if (hasPendingCodeBlock) renderedSegments.lastOrNull() as? RenderedSegment.CodeBlock else null

      val reset = DirtyFlag.RECREATE_SEGMENTS in dirtyFlags
      val forceHeight = DirtyFlag.FORCE_HEIGHT in dirtyFlags
      dirtyFlags.clear()

      val result =
        SegmentReconciler.reconcile(
          currentViews = segmentViews.toList(),
          currentSignatures = segmentSignatures.toList(),
          renderedSegments = renderedSegments,
          reset = reset,
          matchesKind = ::viewMatchesSegmentKind,
          createView = { segment ->
            val view = createSegmentView(segment, style)
            animateNewView(view, segment)
            view
          },
          updateView = { view, segment -> updateSegmentView(view, segment) },
        )

      result.viewsToRemove.forEach { removeView(it) }
      result.viewsToAttach.forEach { addView(it) }

      segmentViews.clear()
      segmentViews.addAll(result.views)
      segmentSignatures.clear()
      segmentSignatures.addAll(result.signatures)

      // A just-closed block has unchanged content, so the reconciler reuses it
      // without an update; sync pending here to trigger its deferred highlight.
      segmentViews.forEachIndexed { index, view ->
        if (view is CodeBlockContainerView) {
          view.pending = pendingCodeBlockSegment != null && index == segmentViews.size - 1
        }
      }

      val topologyChanged = result.viewsToAttach.isNotEmpty() || result.viewsToRemove.isNotEmpty()

      if (width > 0) {
        val heightBefore = computeSegmentsTotalHeight()
        layoutSegments()
        val heightAfter = computeSegmentsTotalHeight()

        if (forceHeight || topologyChanged || heightBefore != heightAfter) {
          MeasurementStore.invalidate(id)
          requestLayout()
        }
      }
    }

    private fun viewMatchesSegmentKind(
      view: View,
      segment: RenderedSegment,
    ): Boolean =
      when (segment) {
        is RenderedSegment.Text -> view is EnrichedMarkdownInternalText
        is RenderedSegment.Table -> view is TableContainerView
        is RenderedSegment.Math -> isMathContainerView(view)
        is RenderedSegment.CodeBlock -> view is CodeBlockContainerView
      }

    private fun isMathContainerView(view: View): Boolean = mathContainerClass?.isInstance(view) == true

    private fun createSegmentView(
      segment: RenderedSegment,
      style: StyleConfig,
    ): View =
      when (segment) {
        is RenderedSegment.Text -> createTextView(segment)
        is RenderedSegment.Table -> createTableView(segment, style)
        is RenderedSegment.Math -> createMathView(segment, style)
        is RenderedSegment.CodeBlock -> createCodeBlockView(segment, style)
      }

    private fun updateSegmentView(
      view: View,
      segment: RenderedSegment,
    ) {
      when (segment) {
        is RenderedSegment.Text -> {
          val textView = view as EnrichedMarkdownInternalText
          val tailStart = textView.text?.length ?: 0
          textView.lastElementMarginBottom = segment.lastElementMarginBottom
          textView.applyStyledText(segment.styledText)
          segment.imageSpans.forEach { it.registerTextView(textView) }
          animateTextViewTail(textView, tailStart)
        }

        is RenderedSegment.Table -> {
          val tableView = view as TableContainerView
          val previousRowCount = tableView.rowCount
          tableView.applyTableNode(segment.node)
          if (streamingAnimation && !isReducedMotionEnabled(context)) {
            tableView.animateNewRows(previousRowCount, BLOCK_FADE_DURATION_MS)
          }
        }

        is RenderedSegment.Math -> {
          mathContainerClass
            ?.getMethod("applyLatex", String::class.java)
            ?.invoke(view, segment.latex)
        }

        is RenderedSegment.CodeBlock -> {
          (view as CodeBlockContainerView).apply {
            pending = segment === pendingCodeBlockSegment
            applyCodeBlockNode(segment.node)
          }
        }
      }
    }

    private fun animateNewView(
      view: View,
      segment: RenderedSegment,
    ) {
      if (!streamingAnimation) return
      when (segment) {
        is RenderedSegment.Text -> animateTextViewTail(view as EnrichedMarkdownInternalText, 0)
        is RenderedSegment.Table, is RenderedSegment.Math, is RenderedSegment.CodeBlock -> animateBlockViewFadeIn(view)
      }
    }

    private fun animateTextViewTail(
      view: EnrichedMarkdownInternalText,
      tailStart: Int,
    ) {
      if (!streamingAnimation) return
      val textLength = view.text?.length ?: 0
      if (textLength <= tailStart) return
      TailFadeInAnimator(view).animate(tailStart, textLength)
    }

    private fun animateBlockViewFadeIn(view: View) {
      if (!streamingAnimation) return
      if (isReducedMotionEnabled(context)) return
      view.alpha = 0f
      view
        .animate()
        .alpha(1f)
        .setDuration(BLOCK_FADE_DURATION_MS)
        .start()
    }

    private fun createTextView(segment: RenderedSegment.Text) =
      EnrichedMarkdownInternalText(context).apply {
        spoilerOverlay = this@EnrichedMarkdown.spoilerOverlay
        enableTaskListItemToggle = this@EnrichedMarkdown.enableTaskListItemToggle
        selectionMenuConfig = this@EnrichedMarkdown.selectionMenuConfig
        accessibilityLabels = this@EnrichedMarkdown.accessibilityLabels
        setIsSelectable(selectable)
        markdownStyle?.paragraphStyle?.fontSize?.let { setTextSize(android.util.TypedValue.COMPLEX_UNIT_PX, it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          breakStrategy = BreakStrategyUtils.resolveBreakStrategy(textBreakStrategy)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && segment.needsJustify) {
          justificationMode = android.text.Layout.JUSTIFICATION_MODE_INTER_WORD
        }
        lastElementMarginBottom = segment.lastElementMarginBottom
        applyStyledText(segment.styledText)
        segment.imageSpans.forEach { it.registerTextView(this) }

        onTaskListItemPressCallback = { taskIndex, checked, itemText ->
          this@EnrichedMarkdown.onTaskListItemPressCallback?.invoke(taskIndex, checked, itemText)
        }

        if (contextMenuItemTexts.isNotEmpty()) {
          setContextMenuItems(contextMenuItemTexts, ::forwardContextMenuItemPress)
        }

        applySelectionColors(selectionColor, selectionHandleColor)
      }

    private fun createTableView(
      segment: RenderedSegment.Table,
      style: StyleConfig,
    ) = TableContainerView(context, style).apply {
      allowFontScaling = this@EnrichedMarkdown.allowFontScaling
      maxFontSizeMultiplier = this@EnrichedMarkdown.maxFontSizeMultiplier
      accessibilityLabels = this@EnrichedMarkdown.accessibilityLabels
      onLinkPress = onLinkPressCallback
      onLinkLongPress = onLinkLongPressCallback
      copyLabel = this@EnrichedMarkdown.selectionMenuConfig.copyLabel
      copyAsMarkdownLabel = this@EnrichedMarkdown.selectionMenuConfig.copyAsMarkdownLabel
      applyTableNode(segment.node)
    }

    private fun createCodeBlockView(
      segment: RenderedSegment.CodeBlock,
      style: StyleConfig,
    ) = CodeBlockContainerView(context, style).apply {
      copyLabel = this@EnrichedMarkdown.selectionMenuConfig.copyLabel
      copyAsMarkdownLabel = this@EnrichedMarkdown.selectionMenuConfig.copyAsMarkdownLabel
      onCopyPress = { code, language ->
        this@EnrichedMarkdown.onCopyPressCallback?.invoke(code, language)
      }
      pending = segment === pendingCodeBlockSegment
      applyCodeBlockNode(segment.node)
    }

    private fun createMathView(
      segment: RenderedSegment.Math,
      style: StyleConfig,
    ): View {
      val resolvedClass = mathContainerClass
      if (!FeatureFlags.IS_MATH_ENABLED || resolvedClass == null) return View(context)
      return try {
        val view =
          resolvedClass
            .getConstructor(Context::class.java, StyleConfig::class.java)
            .newInstance(context, style) as View
        runCatching {
          resolvedClass
            .getMethod("setAccessibilityLabels", AccessibilityLabels::class.java)
            .invoke(view, accessibilityLabels)
        }
        resolvedClass
          .getMethod("setCopyLabel", String::class.java)
          .invoke(view, selectionMenuConfig.copyLabel)
        resolvedClass
          .getMethod("setCopyAsMarkdownLabel", String::class.java)
          .invoke(view, selectionMenuConfig.copyAsMarkdownLabel)
        resolvedClass.getMethod("applyLatex", String::class.java).invoke(view, segment.latex)
        view
      } catch (e: Exception) {
        Log.e(TAG, "Failed to create math view", e)
        View(context)
      }
    }

    private fun postToMain(
      renderId: Long,
      action: () -> Unit,
    ) {
      mainHandler.post {
        if (renderId == currentRenderId) action()
      }
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

    fun onImageLayoutChanged() {
      if (width > 0) {
        layoutSegments()
        requestLayout()
      }
      MeasurementStore.invalidate(id)
      val wrapper = stateWrapper ?: return
      val state = Arguments.createMap()
      state.putInt("forceHeightRecalculationCounter", ++forceHeightRecalculationCounter)
      wrapper.updateState(state)
    }

    private fun layoutSegments() {
      val containerWidth = width
      if (containerWidth <= 0) return

      val needsOverhang =
        segmentViews.any { view ->
          view is TableContainerView &&
            ceil(view.tableStyle.horizontalOverflow.toDouble()).toInt() > 0
        }
      if (clipChildren == needsOverhang) {
        clipChildren = !needsOverhang
      }

      var currentY = 0
      val lastIndex = segmentViews.lastIndex
      val widthSpec = MeasureSpec.makeMeasureSpec(containerWidth, MeasureSpec.EXACTLY)
      val heightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)

      segmentViews.forEachIndexed { index, view ->
        val segment = view as? BlockSegmentView
        val shouldAddBottomMargin = index != lastIndex || allowTrailingMargin

        currentY += segment?.segmentMarginTop ?: 0

        val overhang =
          if (view is TableContainerView) {
            max(ceil(view.tableStyle.horizontalOverflow.toDouble()).toInt(), 0)
          } else {
            0
          }

        if (overhang > 0) {
          val extendedWidth = containerWidth + overhang * 2
          val extWidthSpec = MeasureSpec.makeMeasureSpec(extendedWidth, MeasureSpec.EXACTLY)
          view.measure(extWidthSpec, heightSpec)
          view.layout(-overhang, currentY, containerWidth + overhang, currentY + view.measuredHeight)
        } else {
          view.measure(widthSpec, heightSpec)
          view.layout(0, currentY, containerWidth, currentY + view.measuredHeight)
        }
        currentY += view.measuredHeight

        if (shouldAddBottomMargin) {
          currentY += segment?.segmentMarginBottom ?: 0
        }
      }
    }

    private fun computeSegmentsTotalHeight(): Int {
      var totalHeight = 0
      val lastIndex = segmentViews.lastIndex
      segmentViews.forEachIndexed { index, view ->
        val segment = view as? BlockSegmentView
        totalHeight += segment?.segmentMarginTop ?: 0
        totalHeight += view.measuredHeight
        if (index != lastIndex || allowTrailingMargin) {
          totalHeight += segment?.segmentMarginBottom ?: 0
        }
      }
      return totalHeight
    }

    fun cleanup() {
      executor.shutdownNow()
    }

    companion object {
      private const val TAG = "EnrichedMarkdown"
      private const val BLOCK_FADE_DURATION_MS = 200L
    }
  }
