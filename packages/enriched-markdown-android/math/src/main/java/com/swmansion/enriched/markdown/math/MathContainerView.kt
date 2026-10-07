package com.swmansion.enriched.markdown.math

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.segments.BlockSegmentView
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import com.swmansion.enriched.markdown.views.ContextMenuPopup
import io.ratex.RaTeXRenderer
import kotlin.math.ceil

/**
 * Block segment for display math (`$$...$$`): the equation, horizontally scrollable when it is
 * wider than the view, with a long-press menu that copies it as latex or as markdown.
 *
 * The style is read once, at construction. That is not a cache to invalidate: a new
 * [StyleConfig] makes core rebuild every segment view, exactly as it does for tables.
 */
class MathContainerView(
  context: Context,
  styleConfig: StyleConfig,
  var selectionMenuConfig: SelectionMenuConfig = SelectionMenuConfig(),
) : FrameLayout(context),
  BlockSegmentView {
  private val mathStyle: MathStyle = styleConfig.mathStyle(context)
  private val scrollView = HorizontalScrollView(context)
  private val mathView = RaTeXCanvasView(context)

  var latex: String = ""
    private set

  override val segmentMarginTop: Int get() = mathStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = mathStyle.marginBottom.toInt()

  // LEFT and RIGHT are absolute sides, so unlike START and END they must not flip in RTL layouts.
  private val mathGravity =
    when (mathStyle.textAlign) {
      TextAlignment.START, TextAlignment.AUTO, TextAlignment.JUSTIFY -> Gravity.START
      TextAlignment.END -> Gravity.END
      TextAlignment.LEFT -> Gravity.LEFT
      TextAlignment.RIGHT -> Gravity.RIGHT
      TextAlignment.CENTER -> Gravity.CENTER_HORIZONTAL
    }

  init {
    setBackgroundColor(mathStyle.backgroundColor)

    val paddingPx = mathStyle.padding.toInt()

    val mathWrapper =
      FrameLayout(context).apply {
        setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
        // The wrapper fills the scroll viewport, so it is what a press anywhere in the block lands
        // on; the scroll view itself swallows touches and never reports a long press.
        setOnLongClickListener { view -> showContextMenu(view) }
      }
    mathWrapper.addView(
      mathView,
      LayoutParams(WRAP_CONTENT, WRAP_CONTENT).apply {
        gravity = mathGravity
      },
    )

    scrollView.apply {
      isHorizontalScrollBarEnabled = true
      overScrollMode = View.OVER_SCROLL_NEVER
      isFillViewport = true
      importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS
      addView(mathWrapper, LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
    }

    addView(scrollView, LayoutParams(MATCH_PARENT, WRAP_CONTENT))

    isFocusable = true
    ViewCompat.setScreenReaderFocusable(this, true)
    importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_YES
    updateAccessibilityLabel()

    setOnLongClickListener { view -> showContextMenu(view) }
  }

  internal fun applyPayload(payload: MathSegmentPayload) {
    latex = payload.latex
    val renderer = payload.renderer
    if (renderer != null) {
      mathView.renderer = renderer
      mathView.fallbackText = null
    } else {
      showSource()
    }
    mathView.requestLayout()
    mathView.invalidate()
    updateAccessibilityLabel()
  }

  /** The engine rejected [latex], which the segment already reported when it was rendered. */
  private fun showSource() {
    mathView.renderer = null
    mathView.fallbackText = "\$\$" + latex + "\$\$"
    mathView.fallbackColor = mathStyle.color
    mathView.fallbackFontSize = mathStyle.fontSize
  }

  private fun updateAccessibilityLabel() {
    contentDescription = "Math: $latex"
  }

  private fun showContextMenu(anchor: View): Boolean {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    ContextMenuPopup.show(anchor, this) {
      item(ContextMenuPopup.Icon.COPY, context.getString(android.R.string.copy)) {
        clipboard.setPrimaryClip(ClipData.newPlainText("Math", latex))
      }
      if (selectionMenuConfig.copyAsMarkdown) {
        item(
          ContextMenuPopup.Icon.DOCUMENT,
          selectionMenuConfig.resolvedCopyAsMarkdownLabel,
        ) {
          clipboard.setPrimaryClip(ClipData.newPlainText("Math", "$$\n$latex\n$$"))
        }
      }
    }
    return true
  }

  /** Draws whatever the engine produced, or the source when it produced nothing. */
  private class RaTeXCanvasView(
    context: Context,
  ) : View(context) {
    var renderer: RaTeXRenderer? = null

    var fallbackText: String? = null
    var fallbackColor: Int = 0
    var fallbackFontSize: Float = 0f
    private val fallbackPaint = Paint(Paint.ANTI_ALIAS_FLAG)

    override fun onMeasure(
      widthMeasureSpec: Int,
      heightMeasureSpec: Int,
    ) {
      val currentRenderer = renderer
      if (currentRenderer != null) {
        setMeasuredDimension(
          ceil(currentRenderer.widthPx).toInt().coerceAtLeast(1),
          ceil(currentRenderer.totalHeightPx).toInt().coerceAtLeast(1),
        )
        return
      }

      val fallback = fallbackText
      if (fallback != null) {
        fallbackPaint.textSize = fallbackFontSize
        val metrics = fallbackPaint.fontMetrics
        setMeasuredDimension(
          ceil(fallbackPaint.measureText(fallback)).toInt().coerceAtLeast(1),
          ceil(metrics.descent - metrics.ascent).toInt().coerceAtLeast(1),
        )
        return
      }

      setMeasuredDimension(0, 0)
    }

    override fun onDraw(canvas: Canvas) {
      val currentRenderer = renderer
      if (currentRenderer != null) {
        currentRenderer.draw(canvas)
        return
      }

      val fallback = fallbackText ?: return
      fallbackPaint.textSize = fallbackFontSize
      fallbackPaint.color = fallbackColor
      canvas.drawText(fallback, 0f, -fallbackPaint.fontMetrics.ascent, fallbackPaint)
    }
  }
}
