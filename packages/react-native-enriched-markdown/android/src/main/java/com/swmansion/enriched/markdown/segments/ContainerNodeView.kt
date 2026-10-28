package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import kotlin.math.ceil
import kotlin.math.max

/**
 * Reusable view for an AST branch node that holds a vertical stack of block
 * children (the document root and every blockquote). It owns the machinery
 * shared by both: reconciling a list of RenderedSegment into real child views
 * by signature, stacking them vertically with per-segment margins, and
 * reporting the total height (including its own vertical padding).
 *
 * Per-kind view construction is delegated to a SegmentViewFactory the subclass
 * supplies, so root-only wiring (link/copy callbacks, selection menu, spoiler,
 * accessibility, task-list toggle, pending code block) lives with the root and
 * the nested blockquote factory reuses only the shared creators.
 *
 * Layout honors paddingLeft/Top/Right/Bottom so a subclass can inset its
 * children (e.g. a blockquote's border/gap/padding) via padding: children are
 * measured at exactly width - paddingLeft - paddingRight and laid out starting
 * at (paddingLeft, paddingTop). The root uses zero padding, so its behavior is
 * unchanged.
 */
open class ContainerNodeView(
  context: Context,
) : FrameLayout(context) {
  protected val segmentViews = mutableListOf<View>()
  protected val segmentSignatures = mutableListOf<Long>()

  protected lateinit var segmentViewFactory: SegmentViewFactory

  protected var trailingMarginEnabled: Boolean = false

  // Code block views in document order, descending into nested blockquotes: the
  // order CodeBlockWrapState indexes them in.
  internal fun codeBlockViews(): Sequence<CodeBlockContainerView> =
    sequence {
      segmentViews.forEach { view ->
        when (view) {
          is CodeBlockContainerView -> yield(view)
          is ContainerNodeView -> yieldAll(view.codeBlockViews())
        }
      }
    }

  /**
   * Pushes the slot heights the shadow node measured into every placeholder,
   * recursing into nested containers; a missing id collapses the slot. Returns
   * whether any height changed.
   */
  internal fun applyBlockSlotHeights(heights: Map<String, Int>): Boolean {
    var changed = false
    segmentViews.forEach { view ->
      when (view) {
        is BlockSlotSegmentView -> {
          val height = heights[view.slotId] ?: 0
          if (view.slotHeight != height) {
            view.slotHeight = height
            changed = true
          }
        }

        is ContainerNodeView -> {
          if (view.applyBlockSlotHeights(heights)) changed = true
        }
      }
    }
    return changed
  }

  // The host's slot views by id; a nested container reaches them through its parent.
  internal open fun slotViewsForAccessibility(): Map<String, View> =
    (parent as? ContainerNodeView)?.slotViewsForAccessibility() ?: emptyMap()

  // A container read as a whole (a quote is long-clickable, so important) still
  // lists its own children here, and its placeholders give way to slot views too.
  override fun addChildrenForAccessibility(outChildren: ArrayList<View>) {
    val slotViews = slotViewsForAccessibility()
    if (slotViews.isEmpty()) {
      super.addChildrenForAccessibility(outChildren)
      return
    }
    addSegmentsForAccessibility(slotViews, outChildren)
  }

  /**
   * The views accessibility reads, in document order: each placeholder gives way
   * to the slot view standing in for it, and nested containers are flattened,
   * so a React replacement is read where its block sits.
   */
  internal fun addSegmentsForAccessibility(
    slotViews: Map<String, View>,
    outChildren: ArrayList<View>,
  ) {
    segmentViews.forEach { view ->
      when {
        view is BlockSlotSegmentView -> {
          slotViews[view.slotId]?.let { addForAccessibility(it, outChildren) }
        }

        view is ContainerNodeView && !view.isImportantForAccessibility -> {
          view.addSegmentsForAccessibility(slotViews, outChildren)
        }

        else -> {
          addForAccessibility(view, outChildren)
        }
      }
    }
  }

  // An important view is read itself, an unimportant group through its
  // children. Leaves are kept either way: the framework's own filter
  // (includeForAccessibility) is hidden, and services that ask for unimportant
  // views, as UI test tools do, would lose them.
  private fun addForAccessibility(
    view: View,
    outChildren: ArrayList<View>,
  ) {
    if (view.visibility != VISIBLE) return
    if (view.isImportantForAccessibility || view !is ViewGroup) {
      outChildren.add(view)
    } else {
      view.addChildrenForAccessibility(outChildren)
    }
  }

  internal fun forEachBlockSlot(action: (BlockSlotSegmentView) -> Unit) {
    segmentViews.forEach { view ->
      when (view) {
        is BlockSlotSegmentView -> action(view)
        is ContainerNodeView -> view.forEachBlockSlot(action)
      }
    }
  }

  /**
   * Reconciles the current child views against renderedSegments, attaching and
   * removing views as needed and updating segmentViews/segmentSignatures.
   * Returns whether the topology changed (any view attached or removed).
   */
  protected fun applySegments(
    renderedSegments: List<RenderedSegment>,
    reset: Boolean,
  ): Boolean {
    val result =
      SegmentReconciler.reconcile(
        currentViews = segmentViews.toList(),
        currentSignatures = segmentSignatures.toList(),
        renderedSegments = renderedSegments,
        reset = reset,
        matchesKind = segmentViewFactory::matchesKind,
        createView = { segment ->
          val view = segmentViewFactory.createView(segment)
          segmentViewFactory.animateNewView(view, segment)
          view
        },
        updateView = { view, segment -> segmentViewFactory.updateView(view, segment) },
      )

    result.viewsToRemove.forEach { removeView(it) }
    result.viewsToAttach.forEach { addView(it) }

    // Only created views are appended, so a signature-based reorder would leave
    // getChildAt out of step with segmentViews. detach/attach splices the child array
    // without a detach-from-window pass, so a moved child keeps its selection, focus
    // and scroll state; each step fixes one index without disturbing the ones before it.
    // Segments take the first indices, so a host's slot layer stays the last child.
    result.views.forEachIndexed { index, view ->
      if (getChildAt(index) !== view) {
        detachViewFromParent(view)
        attachViewToParent(view, index, view.layoutParams)
      }
    }

    segmentViews.clear()
    segmentViews.addAll(result.views)
    segmentSignatures.clear()
    segmentSignatures.addAll(result.signatures)

    return result.viewsToAttach.isNotEmpty() || result.viewsToRemove.isNotEmpty()
  }

  protected fun layoutSegments() {
    val containerWidth = width
    if (containerWidth <= 0) return

    val contentWidth = (containerWidth - paddingLeft - paddingRight).coerceAtLeast(0)

    val needsOverhang =
      segmentViews.any { view ->
        view is TableContainerView &&
          ceil(view.tableStyle.horizontalOverflow.toDouble()).toInt() > 0
      }
    if (clipChildren == needsOverhang) {
      clipChildren = !needsOverhang
    }

    var currentY = paddingTop
    val lastIndex = segmentViews.lastIndex
    val widthSpec = MeasureSpec.makeMeasureSpec(contentWidth, MeasureSpec.EXACTLY)
    val heightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)

    segmentViews.forEachIndexed { index, view ->
      val segment = view as? BlockSegmentView
      val shouldAddBottomMargin = index != lastIndex || trailingMarginEnabled

      currentY += segment?.segmentMarginTop ?: 0

      val overhang =
        if (view is TableContainerView) {
          max(ceil(view.tableStyle.horizontalOverflow.toDouble()).toInt(), 0)
        } else {
          0
        }

      if (overhang > 0) {
        val extendedWidth = contentWidth + overhang * 2
        val extWidthSpec = MeasureSpec.makeMeasureSpec(extendedWidth, MeasureSpec.EXACTLY)
        view.measure(extWidthSpec, heightSpec)
        view.layout(
          paddingLeft - overhang,
          currentY,
          paddingLeft + contentWidth + overhang,
          currentY + view.measuredHeight,
        )
      } else {
        view.measure(widthSpec, heightSpec)
        view.layout(paddingLeft, currentY, paddingLeft + contentWidth, currentY + view.measuredHeight)
      }
      currentY += view.measuredHeight

      if (shouldAddBottomMargin) {
        currentY += segment?.segmentMarginBottom ?: 0
      }
    }
  }

  /**
   * Measures every child at the inner content width so computeSegmentsTotalHeight
   * can read accurate measuredHeights during a subclass's onMeasure, before the
   * onLayout pass runs layoutSegments. Without this a container that sizes itself
   * from its children (a blockquote) would measure them as zero-height and clip.
   */
  protected fun measureSegmentChildren(outerWidth: Int) {
    val contentWidth = (outerWidth - paddingLeft - paddingRight).coerceAtLeast(0)
    val widthSpec = MeasureSpec.makeMeasureSpec(contentWidth, MeasureSpec.EXACTLY)
    val heightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)
    segmentViews.forEach { it.measure(widthSpec, heightSpec) }
  }

  protected fun computeSegmentsTotalHeight(): Int {
    var totalHeight = paddingTop + paddingBottom
    val lastIndex = segmentViews.lastIndex
    segmentViews.forEachIndexed { index, view ->
      val segment = view as? BlockSegmentView
      totalHeight += segment?.segmentMarginTop ?: 0
      // A slot growing into place takes its share in the layout only.
      totalHeight += (view as? BlockSlotSegmentView)?.slotHeight ?: view.measuredHeight
      if (index != lastIndex || trailingMarginEnabled) {
        totalHeight += segment?.segmentMarginBottom ?: 0
      }
    }
    return totalHeight
  }
}
