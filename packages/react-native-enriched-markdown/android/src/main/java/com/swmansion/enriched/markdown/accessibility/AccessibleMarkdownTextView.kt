package com.swmansion.enriched.markdown.accessibility

import android.content.Context
import android.graphics.Canvas
import android.graphics.Rect
import android.text.Spannable
import android.util.AttributeSet
import android.view.ActionMode
import android.view.KeyEvent
import android.view.MotionEvent
import androidx.appcompat.widget.AppCompatTextView
import com.swmansion.enriched.markdown.spans.LinkPillSpan
import com.swmansion.enriched.markdown.spans.TextBackgroundDrawer
import com.swmansion.enriched.markdown.utils.text.span.prepareWidthAwareSpans
import com.swmansion.enriched.markdown.utils.text.view.OnSelectionCopy
import com.swmansion.enriched.markdown.utils.text.view.SelectionCopyFormat
import com.swmansion.enriched.markdown.utils.text.view.copySelection
import com.swmansion.enriched.markdown.utils.text.view.replaceAdoptedTextTail

/** AppCompatTextView with built-in TalkBack support via MarkdownAccessibilityHelper. */
abstract class AccessibleMarkdownTextView
  @JvmOverloads
  constructor(
    context: Context,
    attrs: AttributeSet? = null,
    defStyleAttr: Int = 0,
  ) : AppCompatTextView(context, attrs, defStyleAttr) {
    val accessibilityHelper = MarkdownAccessibilityHelper(this)
    var onSelectionCopyCallback: OnSelectionCopy? = null

    /** The selection toolbar while it is showing, kept up to date by the selection menu callback. */
    internal var selectionActionMode: ActionMode? = null

    // Inline code and highlight backgrounds come from the layout that draws the text, under it.
    // Made on first draw: setText runs from the TextView constructor, before fields are set.
    private var textBackgrounds: TextBackgroundDrawer? = null

    override fun onDraw(canvas: Canvas) {
      val drawer = textBackgrounds ?: TextBackgroundDrawer().also { textBackgrounds = it }
      drawer.draw(canvas, this)
      super.onDraw(canvas)
    }

    // The selection menu's Copy ends up here, and Ctrl+C (and TalkBack's copy action) call this directly.
    override fun onTextContextMenuItem(id: Int): Boolean {
      if (id == android.R.id.copy) {
        // The platform's copy is what tells the user when the clipboard refuses the clip.
        if (!copySelection(SelectionCopyFormat.PLAIN, onSelectionCopyCallback)) {
          return super.onTextContextMenuItem(id)
        }
        selectionActionMode?.finish()
        return true
      }
      return super.onTextContextMenuItem(id)
    }

    override fun setText(
      text: CharSequence?,
      type: BufferType?,
    ) {
      prepareSpans(text)
      textBackgrounds?.invalidateFrom(0)
      super.setText(text, type)
    }

    /**
     * Primes pills and images before the layout for [text] is built, and registers for icons that
     * load later. Runs from the TextView constructor too: use nothing initialized after it.
     */
    protected fun prepareSpans(text: CharSequence?) {
      val contentWidth = width - compoundPaddingLeft - compoundPaddingRight
      if (contentWidth > 0) prepareWidthAwareSpans(text, contentWidth)
      LinkPillSpan.registerView(text, this)
    }

    /**
     * Replaces the text from [start] on with [tail]. The layout keeps the lines before the edit
     * (DynamicLayout reflows from the changed paragraph), where setting the whole text would lay
     * all of it out again. False when the view holds no buffer to edit, or its layout wouldn't
     * hear of the edit.
     */
    protected fun replaceTextTail(
      start: Int,
      tail: Spannable,
    ): Boolean {
      prepareSpans(tail)
      if (!replaceAdoptedTextTail(text, start, tail, hasLayout = layout != null)) return false
      textBackgrounds?.invalidateFrom(start)
      // TextView didn't hear of the edit. Without a request, measure() would return the height
      // cached before it.
      requestLayout()
      invalidate()
      accessibilityHelper.invalidateAccessibilityItems()
      return true
    }

    override fun onMeasure(
      widthMeasureSpec: Int,
      heightMeasureSpec: Int,
    ) {
      if (MeasureSpec.getMode(widthMeasureSpec) != MeasureSpec.UNSPECIFIED) {
        val width = (MeasureSpec.getSize(widthMeasureSpec) - compoundPaddingLeft - compoundPaddingRight).coerceAtLeast(1)
        // TextView keeps its layout when the new width still fits the old lines.
        if (prepareWidthAwareSpans(text, width) && layout != null) dropTextLayout()
      }
      super.onMeasure(widthMeasureSpec, heightMeasureSpec)
    }

    /**
     * Makes the next measure build a fresh text layout. TextView exposes no direct way:
     * re-setting the text would copy it and clear the selection, while setting the break
     * strategy, even to its current value, discards the layout and nothing else.
     */
    private fun dropTextLayout() {
      breakStrategy = breakStrategy
    }

    override fun dispatchHoverEvent(event: MotionEvent): Boolean =
      accessibilityHelper.dispatchHoverEvent(event) || super.dispatchHoverEvent(event)

    override fun dispatchKeyEvent(event: KeyEvent): Boolean = accessibilityHelper.dispatchKeyEvent(event) || super.dispatchKeyEvent(event)

    override fun onFocusChanged(
      gainFocus: Boolean,
      direction: Int,
      previouslyFocusedRect: Rect?,
    ) {
      super.onFocusChanged(gainFocus, direction, previouslyFocusedRect)
      accessibilityHelper.onFocusChanged(gainFocus, direction, previouslyFocusedRect)
    }

    override fun onDetachedFromWindow() {
      // Before super, and here rather than in a ViewManager's
      // onDropViewInstance: getViewTreeObserver() returns the WINDOW's observer
      // only while the view is attached. Once detached it hands back the view's
      // own floating observer, so a removal then would target the wrong
      // observer and leave the listener on the window.
      accessibilityHelper.cleanup()
      super.onDetachedFromWindow()
    }
  }
