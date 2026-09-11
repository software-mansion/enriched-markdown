package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.view.View
import android.widget.FrameLayout

/**
 * Reusable FrameLayout for an AST branch node that holds a vertical stack of block
 * children. It reconciles a list of RenderedSegment into real child views by
 * signature, stacks them vertically with per-segment margins, honors its own
 * padding, and reports the total height.
 */
open class ContainerNodeView(
  context: Context,
) : FrameLayout(context) {
  protected val segmentViews = mutableListOf<View>()
  protected val segmentSignatures = mutableListOf<Long>()

  protected lateinit var segmentViewFactory: SegmentViewFactory

  protected var trailingMarginEnabled: Boolean = false

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
        createView = { segment -> segmentViewFactory.createView(segment) },
        updateView = { view, segment -> segmentViewFactory.updateView(view, segment) },
      )

    result.viewsToRemove.forEach { removeView(it) }
    result.viewsToAttach.forEach { addView(it) }

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

    var currentY = paddingTop
    val lastIndex = segmentViews.lastIndex
    val widthSpec = MeasureSpec.makeMeasureSpec(contentWidth, MeasureSpec.EXACTLY)
    val heightSpec = MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED)

    segmentViews.forEachIndexed { index, view ->
      val segment = view as? BlockSegmentView
      val shouldAddBottomMargin = index != lastIndex || trailingMarginEnabled

      currentY += segment?.segmentMarginTop ?: 0

      view.measure(widthSpec, heightSpec)
      view.layout(paddingLeft, currentY, paddingLeft + contentWidth, currentY + view.measuredHeight)
      currentY += view.measuredHeight

      if (shouldAddBottomMargin) {
        currentY += segment?.segmentMarginBottom ?: 0
      }
    }
  }

  /**
   * Measures every child at the inner content width so a container that sizes itself
   * from its children doesn't measure them as zero-height before onLayout runs.
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
      totalHeight += view.measuredHeight
      if (index != lastIndex || trailingMarginEnabled) {
        totalHeight += segment?.segmentMarginBottom ?: 0
      }
    }
    return totalHeight
  }
}
