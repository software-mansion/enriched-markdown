package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.graphics.Paint
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import com.swmansion.enriched.markdown.CodeBlockWrapCursor
import com.swmansion.enriched.markdown.MeasurementStore
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.extensions.replaceMathSpansWithPlaceholders
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import kotlin.math.ceil

/** A stack's height and, for the root stack, the widest text line (px). */
data class StackMeasurement(
  val heightPx: Float,
  val maxContentWidthPx: Float,
)

/**
 * View-free height summation for a vertical stack of RenderedSegments at a fixed
 * content width: the one walk the shadow-node measurement pass (MeasurementStore,
 * root stack) and the blockquote container's static measurer (nested stacks) share,
 * so the two can never report different heights.
 *
 * Math heights must be measured up front on the main thread by the caller and
 * supplied through mathHeightForIndex, because the summation runs off the main
 * thread. Blockquote children recurse through
 * BlockquoteContainerView.measureBlockquoteNodeHeight. wrapCursor, when given,
 * says which code blocks the user wrapped; it is shared down the recursion so
 * nested blocks keep counting in document order.
 */
object SegmentHeightMeasurer {
  /** The host's root stack: outermost quotes carry their margins and the widest line is tracked. */
  fun measureRootStack(
    segments: List<RenderedSegment>,
    style: StyleConfig,
    context: Context,
    contentWidthPx: Float,
    fontSizePx: Float,
    breakStrategy: Int,
    allowTrailingMargin: Boolean,
    mathHeightForIndex: (Int) -> Float,
    wrapCursor: CodeBlockWrapCursor? = null,
    slotMeasurer: BlockSlotMeasurer? = null,
  ): StackMeasurement =
    measure(
      segments,
      style,
      context,
      contentWidthPx,
      fontSizePx,
      breakStrategy,
      allowTrailingMargin,
      mathHeightForIndex,
      wrapCursor,
      slotMeasurer,
      originXPx = 0f,
      originYPx = 0f,
      nested = false,
    )

  /** A stack nested inside a quote: no quote margins (the parent's padding separates them). */
  fun measureSegmentsHeight(
    segments: List<RenderedSegment>,
    style: StyleConfig,
    context: Context,
    contentWidthPx: Float,
    fontSizePx: Float,
    breakStrategy: Int,
    allowTrailingMargin: Boolean,
    mathHeightForIndex: (Int) -> Float,
    wrapCursor: CodeBlockWrapCursor? = null,
    // Slot children are measured at their absolute origin (px, within the host
    // content box); the sum below is their y relative to this stack's origin.
    slotMeasurer: BlockSlotMeasurer? = null,
    originXPx: Float = 0f,
    originYPx: Float = 0f,
  ): Float =
    measure(
      segments,
      style,
      context,
      contentWidthPx,
      fontSizePx,
      breakStrategy,
      allowTrailingMargin,
      mathHeightForIndex,
      wrapCursor,
      slotMeasurer,
      originXPx,
      originYPx,
      nested = true,
    ).heightPx

  private fun measure(
    segments: List<RenderedSegment>,
    style: StyleConfig,
    context: Context,
    contentWidthPx: Float,
    fontSizePx: Float,
    breakStrategy: Int,
    allowTrailingMargin: Boolean,
    mathHeightForIndex: (Int) -> Float,
    wrapCursor: CodeBlockWrapCursor?,
    slotMeasurer: BlockSlotMeasurer?,
    originXPx: Float,
    originYPx: Float,
    nested: Boolean,
  ): StackMeasurement {
    val widthPx = ceil(contentWidthPx).toInt().coerceAtLeast(1)
    val lastIndex = segments.lastIndex
    var totalHeightPx = 0f
    var maxContentWidthPx = 0f

    for ((index, segment) in segments.withIndex()) {
      val isLastSegment = index == lastIndex
      val includeBottomMargin = if (isLastSegment) allowTrailingMargin else true

      when (segment) {
        is RenderedSegment.Text -> {
          segment.styledText.replaceMathSpansWithPlaceholders(context)
          val layout = createStaticLayout(segment.styledText, fontSizePx, widthPx, breakStrategy)
          totalHeightPx += layout.height
          val widestLine = (0 until layout.lineCount).maxOfOrNull { layout.getLineWidth(it) } ?: 0f
          maxContentWidthPx = maxOf(maxContentWidthPx, ceil(widestLine))
          if (includeBottomMargin) {
            totalHeightPx += segment.lastElementMarginBottom
          }
        }

        is RenderedSegment.Table -> {
          totalHeightPx += style.tableStyle.marginTop.toInt()
          totalHeightPx += TableContainerView.measureTableNodeHeight(segment.node, style, context)
          maxContentWidthPx = contentWidthPx
          if (includeBottomMargin) {
            totalHeightPx += style.tableStyle.marginBottom.toInt()
          }
        }

        is RenderedSegment.Math -> {
          totalHeightPx += style.mathStyle.marginTop.toInt()
          totalHeightPx += mathHeightForIndex(index)
          maxContentWidthPx = contentWidthPx
          if (includeBottomMargin) {
            totalHeightPx += style.mathStyle.marginBottom.toInt()
          }
        }

        is RenderedSegment.CodeBlock -> {
          totalHeightPx += style.codeBlockStyle.marginTop.toInt()
          totalHeightPx +=
            CodeBlockContainerView.measureCodeBlockNodeHeight(
              segment.node,
              style,
              context,
              contentWidthPx,
              wrapCursor?.nextIsWrapped() ?: false,
            )
          maxContentWidthPx = contentWidthPx
          if (includeBottomMargin) {
            totalHeightPx += style.codeBlockStyle.marginBottom.toInt()
          }
        }

        is RenderedSegment.Blockquote -> {
          // Only the outermost quote carries vertical margins; a quote nested in
          // another is separated by the parent's padding alone (BlockquoteContainerView.nested).
          if (!nested) totalHeightPx += style.blockquoteStyle.marginTop.toInt()
          totalHeightPx +=
            BlockquoteContainerView.measureBlockquoteNodeHeight(
              segment.node,
              style,
              context,
              contentWidthPx,
              wrapCursor,
              slotMeasurer,
              originXPx,
              originYPx + totalHeightPx,
            )
          maxContentWidthPx = contentWidthPx
          if (!nested && includeBottomMargin) totalHeightPx += style.blockquoteStyle.marginBottom.toInt()
        }

        is RenderedSegment.BlockSlot -> {
          totalHeightPx += segment.kind.marginTop(style)
          totalHeightPx +=
            slotMeasurer?.measure(segment.slotId, originXPx, originYPx + totalHeightPx, contentWidthPx)?.toInt() ?: 0
          maxContentWidthPx = contentWidthPx
          if (includeBottomMargin) {
            totalHeightPx += segment.kind.marginBottom(style)
          }
        }

        is RenderedSegment.Video -> {
          totalHeightPx += style.videoStyle.marginTop.toInt()
          totalHeightPx += contentWidthPx / style.videoStyle.resolvedAspectRatio
          maxContentWidthPx = contentWidthPx
          if (includeBottomMargin) {
            totalHeightPx += style.videoStyle.marginBottom.toInt()
          }
        }
      }
    }
    return StackMeasurement(totalHeightPx, maxContentWidthPx)
  }

  fun createStaticLayout(
    text: CharSequence,
    fontSizePx: Float,
    widthPx: Int,
    breakStrategy: Int,
  ): StaticLayout {
    val paint =
      TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        textSize = fontSizePx
      }
    prepareWidthAwareSpans(text, widthPx)
    return StaticLayout.Builder
      .obtain(text, 0, text.length, paint, widthPx)
      .setIncludePad(false)
      .setLineSpacing(0f, 1f)
      .apply {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
          @Suppress("WrongConstant")
          setBreakStrategy(breakStrategy)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          setUseLineSpacingFromFallbacks(true)
        }
        MeasurementStore.applyUseBoundsForWidth(this)
      }.build()
  }
}
