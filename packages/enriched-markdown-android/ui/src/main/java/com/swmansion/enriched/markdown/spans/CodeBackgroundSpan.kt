@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.spans

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.text.Layout
import android.text.Spanned
import android.text.TextPaint
import android.text.style.LineBackgroundSpan
import android.widget.TextView
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.spoiler.colorWithAlpha
import com.swmansion.enriched.markdown.spoiler.spoilerTextAlpha
import com.swmansion.enriched.markdown.styles.StyleConfig
import java.lang.ref.WeakReference
import kotlin.math.max
import kotlin.math.min

/**
 * Registers this view with every [CodeBackgroundSpan] in [text], so each positions its background
 * from the layout the view draws with. Called wherever rendered markdown is given to a view, next to
 * [ImageSpan.registerTextView].
 */
internal fun TextView.registerCodeBackgrounds(text: CharSequence?) {
  if (text !is Spanned) return
  for (span in text.getSpans(0, text.length, CodeBackgroundSpan::class.java)) {
    span.registerTextView(this)
  }
}

class CodeBackgroundSpan(
  private val styleConfig: StyleConfig,
) : LineBackgroundSpan {
  companion object {
    private const val CORNER_RADIUS = 6.0f
    private const val BORDER_WIDTH = 1.0f

    private val sharedBackgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
    private val sharedBorderPaint =
      Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = BORDER_WIDTH
        strokeJoin = Paint.Join.ROUND
        strokeCap = Paint.Cap.ROUND
      }
  }

  // Reusable drawing objects per instance
  private val rect = RectF()
  private val path = Path()

  // Weak, so a rendered text that outlives its view does not keep the view alive.
  private var textViewRef: WeakReference<TextView>? = null

  override fun drawBackground(
    canvas: Canvas,
    p: Paint,
    left: Int,
    right: Int,
    top: Int,
    baseline: Int,
    bottom: Int,
    text: CharSequence,
    start: Int,
    end: Int,
    lineNum: Int,
  ) {
    if (text !is Spanned) return

    val spanStart = text.getSpanStart(this)
    val spanEnd = text.getSpanEnd(this)
    if (spanStart !in 0 until spanEnd) return

    // A background under a concealed spoiler would outline the hidden code, so it fades in with
    // the text instead.
    val visibility = text.spoilerTextAlpha(maxOf(spanStart, start), minOf(spanEnd, end))
    if (visibility <= 0f) return

    // 1. Determine relative positioning
    val isFirst = spanStart >= start
    val isLast = spanEnd <= end

    // 2. Calculate coordinates
    val finalBottom = adjustBottomForMargin(text, end, bottom)
    // The layout drawing this line, when the view showing the text registered with this span. Its
    // x positions are in the same frame as left and right, which the layout draws from.
    val layout = textViewRef?.get()?.layout?.takeIf { it.text === text }
    // On a line the code continues onto or past, the background runs to the line's glyphs, which
    // only a layout knows for every alignment and direction; without one it runs to the view edges.
    val startX =
      when {
        layout != null && isFirst -> layout.horizontalOnLine(spanStart, lineNum)
        layout != null -> layout.leadingEdge(lineNum)
        isFirst -> left + measuredOffset(text, start, spanStart, p)
        else -> left.toFloat() + InlineBackgroundGeometry.leadingMarginAt(text, start)
      }
    val endX =
      when {
        layout != null && isLast -> layout.horizontalOnLine(spanEnd, lineNum)
        layout != null -> layout.trailingEdge(lineNum)
        isLast -> left + measuredOffset(text, start, spanEnd, p)
        else -> right.toFloat()
      }

    rect.set(min(startX, endX), top.toFloat(), max(startX, endX), finalBottom.toFloat())

    // 3. Apply Style
    val codeStyle = styleConfig.codeStyle
    sharedBackgroundPaint.color = colorWithAlpha(codeStyle.backgroundColor, visibility)
    sharedBorderPaint.color = colorWithAlpha(codeStyle.borderColor, visibility)

    drawShapes(canvas, isFirst, isLast)
  }

  /**
   * Makes this span position itself from [view]'s layout, which is the one that draws it. See
   * [registerCodeBackgrounds].
   */
  fun registerTextView(view: TextView) {
    if (textViewRef?.get() !== view) textViewRef = WeakReference(view)
  }

  /**
   * The x of [offset] on [line]. An offset at the end of a wrapped line also starts the next
   * line, where getPrimaryHorizontal would place it, so the line's trailing edge is used instead.
   */
  private fun Layout.horizontalOnLine(
    offset: Int,
    line: Int,
  ): Float {
    if (offset < getLineEnd(line) || line == lineCount - 1) return getPrimaryHorizontal(offset)
    return trailingEdge(line)
  }

  /** The x where [line]'s first character is drawn: its right edge in right-to-left text. */
  private fun Layout.leadingEdge(line: Int): Float = getPrimaryHorizontal(getLineStart(line))

  /**
   * The x where [line]'s last glyph ends, leaving out trailing whitespace: its left edge in
   * right-to-left text. It is read where the whitespace starts, as getLineLeft and getLineRight
   * round centered lines differently from where the layout draws them. A line broken mid-word has
   * no whitespace to read, and its offset there would start the next line.
   */
  private fun Layout.trailingEdge(line: Int): Float {
    val lineEnd = getLineEnd(line)
    var glyphsEnd = lineEnd
    while (glyphsEnd > getLineStart(line) && text[glyphsEnd - 1].isWhitespace()) glyphsEnd--
    if (glyphsEnd < lineEnd) return getPrimaryHorizontal(glyphsEnd)
    return if (getParagraphDirection(line) == Layout.DIR_RIGHT_TO_LEFT) getLineLeft(line) else getLineRight(line)
  }

  /**
   * The x of [index] relative to the line's left edge, for text drawn by a view that did not
   * register with this span. It measures the line from its start, so it is exact only for
   * left-to-right text aligned to the start; a registered view's layout is exact for any
   * alignment and direction.
   */
  private fun measuredOffset(
    text: Spanned,
    lineStart: Int,
    index: Int,
    paint: Paint,
  ): Float {
    if (index <= lineStart) return InlineBackgroundGeometry.leadingMarginAt(text, lineStart).toFloat()
    val textPaint = paint as? TextPaint ?: TextPaint(paint)
    // getDesiredWidth already adds the paragraph's leading margin.
    return Layout.getDesiredWidth(text, lineStart, index, textPaint)
  }

  private fun drawShapes(
    canvas: Canvas,
    isFirst: Boolean,
    isLast: Boolean,
  ) {
    val radii = createRadii(isFirst, isLast)

    path.reset()
    path.addRoundRect(rect, radii, Path.Direction.CW)
    canvas.drawPath(path, sharedBackgroundPaint)

    if (isFirst && isLast) {
      canvas.drawPath(path, sharedBorderPaint)
    } else {
      drawOpenBorders(canvas, isFirst, isLast)
    }
  }

  private fun drawOpenBorders(
    canvas: Canvas,
    isFirst: Boolean,
    isLast: Boolean,
  ) {
    val r = CORNER_RADIUS
    path.reset()

    if (isFirst) {
      path.moveTo(rect.right, rect.top)
      path.lineTo(rect.left + r, rect.top)
      path.quadTo(rect.left, rect.top, rect.left, rect.top + r)
      path.lineTo(rect.left, rect.bottom - r)
      path.quadTo(rect.left, rect.bottom, rect.left + r, rect.bottom)
      path.lineTo(rect.right, rect.bottom)
    } else if (isLast) {
      path.moveTo(rect.left, rect.top)
      path.lineTo(rect.right - r, rect.top)
      path.quadTo(rect.right, rect.top, rect.right, rect.top + r)
      path.lineTo(rect.right, rect.bottom - r)
      path.quadTo(rect.right, rect.bottom, rect.right - r, rect.bottom)
      path.lineTo(rect.left, rect.bottom)
    } else {
      path.moveTo(rect.left, rect.top)
      path.lineTo(rect.right, rect.top)
      path.moveTo(rect.left, rect.bottom)
      path.lineTo(rect.right, rect.bottom)
    }
    canvas.drawPath(path, sharedBorderPaint)
  }

  private fun createRadii(
    isFirst: Boolean,
    isLast: Boolean,
  ) = when {
    isFirst && isLast -> {
      floatArrayOf(
        CORNER_RADIUS,
        CORNER_RADIUS,
        CORNER_RADIUS,
        CORNER_RADIUS,
        CORNER_RADIUS,
        CORNER_RADIUS,
        CORNER_RADIUS,
        CORNER_RADIUS,
      )
    }

    isFirst -> {
      floatArrayOf(CORNER_RADIUS, CORNER_RADIUS, 0f, 0f, 0f, 0f, CORNER_RADIUS, CORNER_RADIUS)
    }

    isLast -> {
      floatArrayOf(0f, 0f, CORNER_RADIUS, CORNER_RADIUS, CORNER_RADIUS, CORNER_RADIUS, 0f, 0f)
    }

    else -> {
      floatArrayOf(0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f)
    }
  }

  private fun adjustBottomForMargin(
    text: Spanned,
    lineEnd: Int,
    bottom: Int,
  ): Int {
    if (lineEnd <= 0 || lineEnd > text.length || text[lineEnd - 1] != '\n') return bottom
    val marginSpans = text.getSpans(lineEnd - 1, lineEnd, MarginBottomSpan::class.java)
    var adjusted = bottom
    for (span in marginSpans) {
      if (text.getSpanEnd(span) == lineEnd) adjusted -= span.marginBottom.toInt()
    }
    return adjusted
  }
}
