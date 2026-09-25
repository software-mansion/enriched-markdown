package com.swmansion.enriched.markdown.math

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.util.Log
import android.view.Gravity
import android.view.View
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.PopupMenu
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.plugin.PluginEventSink
import com.swmansion.enriched.markdown.segments.BlockSegmentView
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.styles.TextAlignment
import com.swmansion.enriched.markdown.utils.text.view.DEFAULT_COPY_AS_MARKDOWN_LABEL
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import io.ratex.RaTeXEngine
import io.ratex.RaTeXFontLoader
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
) : FrameLayout(context),
  BlockSegmentView {
  private val mathStyle: MathStyle = styleConfig.mathStyle(context)
  private val scrollView = HorizontalScrollView(context)
  private val mathView = RaTeXCanvasView(context)

  var latex: String = ""
    private set

  var selectionMenuConfig: SelectionMenuConfig = SelectionMenuConfig()
  var onPluginEvent: PluginEventSink? = null

  override val segmentMarginTop: Int get() = mathStyle.marginTop.toInt()
  override val segmentMarginBottom: Int get() = mathStyle.marginBottom.toInt()

  private val mathGravity =
    when (mathStyle.textAlign) {
      TextAlignment.START, TextAlignment.LEFT, TextAlignment.AUTO, TextAlignment.JUSTIFY -> Gravity.START
      TextAlignment.END, TextAlignment.RIGHT -> Gravity.END
      TextAlignment.CENTER -> Gravity.CENTER_HORIZONTAL
    }

  init {
    setBackgroundColor(mathStyle.backgroundColor)

    val paddingPx = mathStyle.padding.toInt()

    // A font-loading failure is not fatal here: applyLatex reports it and draws the source.
    runRaTeX { RaTeXFontLoader.ensureLoaded(context) }

    val mathWrapper =
      FrameLayout(context).apply {
        setPadding(paddingPx, paddingPx, paddingPx, paddingPx)
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
    mathView.setOnLongClickListener { view -> showContextMenu(view) }
  }

  /**
   * Lays the equation out for this view. Parsing happens here rather than on the render thread:
   * the display list it produces is drawn by [RaTeXRenderer] on the main thread and is not known
   * to be safe to build anywhere else.
   */
  fun applyLatex(latex: String) {
    this.latex = latex
    runRaTeX(
      onFailure = { error ->
        Log.e(TAG, "Failed to render LaTeX", error)
        mathView.renderer = null
        mathView.fallbackText = "\$\$" + latex + "\$\$"
        mathView.fallbackColor = mathStyle.color
        mathView.fallbackFontSize = mathStyle.fontSize
        onPluginEvent?.emit(LatexErrorEvent(latex, error.message, displayMode = true))
      },
    ) {
      val displayList = RaTeXEngine.parseBlocking(latex, displayMode = true, color = mathStyle.color)
      mathView.renderer = RaTeXRenderer(displayList, mathStyle.fontSize) { RaTeXFontLoader.getTypeface(it) }
      mathView.fallbackText = null
    }
    mathView.requestLayout()
    mathView.invalidate()
    updateAccessibilityLabel()
  }

  private fun updateAccessibilityLabel() {
    contentDescription = "Math: $latex"
  }

  private fun showContextMenu(anchor: View): Boolean {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    val popup = PopupMenu(context, anchor)

    val copyItem = popup.menu.add(context.getString(android.R.string.copy))
    val copyAsMarkdownItem =
      if (selectionMenuConfig.copyAsMarkdown) {
        popup.menu.add(selectionMenuConfig.copyAsMarkdownLabel.ifEmpty { DEFAULT_COPY_AS_MARKDOWN_LABEL })
      } else {
        null
      }

    popup.setOnMenuItemClickListener { item ->
      when (item) {
        copyItem -> {
          clipboard.setPrimaryClip(ClipData.newPlainText("Math", latex))
          true
        }

        copyAsMarkdownItem -> {
          clipboard.setPrimaryClip(ClipData.newPlainText("Math", "$$\n$latex\n$$"))
          true
        }

        else -> {
          false
        }
      }
    }
    popup.show()
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

  private companion object {
    const val TAG = "MathContainerView"
  }
}
