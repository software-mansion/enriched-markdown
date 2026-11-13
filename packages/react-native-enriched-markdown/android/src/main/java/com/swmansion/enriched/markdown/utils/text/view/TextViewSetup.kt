package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.Color
import android.os.Build
import android.text.GetChars
import android.text.SpanWatcher
import android.text.Spannable
import android.text.SpannableString
import android.text.SpannableStringBuilder
import android.text.style.UpdateLayout
import android.view.textclassifier.TextClassifier
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.utils.common.BoundsForWidthUtils
import com.swmansion.enriched.markdown.utils.common.BreakStrategyUtils

/**
 * Adopts the renderer's buffer instead of copying it: the default factory's copy is
 * quadratic in span count. Safe because each segment's buffer is owned by one view.
 */
private object NoCopySpannableFactory : Spannable.Factory() {
  override fun newSpannable(source: CharSequence): Spannable =
    when (source) {
      is SpannableStringBuilder -> InsertionOrderedSpannable(source)
      is Spannable -> source
      else -> SpannableString(source)
    }
}

/**
 * [text] as the markdown text view lays it out. Build every StaticLayout that sizes such
 * a view from this: span order decides which LineHeightSpan wins on a shared line, so a
 * layout over the bare builder can measure lines shorter than the view draws them.
 */
internal fun inViewSpanOrder(text: CharSequence): CharSequence =
  if (text is SpannableStringBuilder) InsertionOrderedSpannable(text) else text

/**
 * Hides that [buffer] is a `SpannableStringBuilder`. Layout reads a builder's paragraph
 * spans in position order rather than insertion order, which paints nested list margins
 * outer-first and pushes nested checkboxes an indent right.
 *
 * Hiding the type has a price, and it is deliberate: every paragraph-span query from
 * `Layout` now goes through the builder's sorted `getSpans` instead of the unsorted fast
 * path the framework reserves for builders. The `layout` benchmark in the example app's
 * `display-benchmark` covers that cost, so it is already accounted for. Do not
 * "optimise" this wrapper away.
 *
 * The builder also names itself to its span watchers, and `DynamicLayout` ignores changes
 * from any text but the one it was built over. [setSpan] reports the change again as this
 * wrapper, so that setting a span again still reflows its line.
 */
private class InsertionOrderedSpannable(
  val buffer: SpannableStringBuilder,
) : Spannable,
  GetChars {
  override val length: Int get() = buffer.length

  override fun get(index: Int): Char = buffer[index]

  override fun subSequence(
    startIndex: Int,
    endIndex: Int,
  ): CharSequence = buffer.subSequence(startIndex, endIndex)

  override fun getChars(
    start: Int,
    end: Int,
    dest: CharArray,
    destoff: Int,
  ) = buffer.getChars(start, end, dest, destoff)

  override fun <T : Any?> getSpans(
    start: Int,
    end: Int,
    type: Class<T>,
  ): Array<T> = buffer.getSpans(start, end, type)

  override fun getSpanStart(tag: Any): Int = buffer.getSpanStart(tag)

  override fun getSpanEnd(tag: Any): Int = buffer.getSpanEnd(tag)

  override fun getSpanFlags(tag: Any): Int = buffer.getSpanFlags(tag)

  override fun nextSpanTransition(
    start: Int,
    limit: Int,
    type: Class<*>?,
  ): Int = buffer.nextSpanTransition(start, limit, type)

  override fun setSpan(
    what: Any,
    start: Int,
    end: Int,
    flags: Int,
  ) {
    val oldStart = buffer.getSpanStart(what)
    val oldEnd = buffer.getSpanEnd(what)
    buffer.setSpan(what, start, end, flags)
    if (what !is UpdateLayout || oldStart < 0) return
    buffer
      .getSpans(minOf(oldStart, start), minOf(maxOf(oldEnd, end), length), SpanWatcher::class.java)
      .forEach { it.onSpanChanged(this, what, oldStart, oldEnd, start, end) }
  }

  override fun removeSpan(what: Any) = buffer.removeSpan(what)

  override fun toString(): String = buffer.toString()
}

/**
 * Repaints [what] without laying the text out again, for a span whose size did not change.
 * Invalidating is not enough: a selectable TextView draws from display lists that only a
 * span change records again. The buffer's own report reaches the view but not its
 * `DynamicLayout`, see [InsertionOrderedSpannable].
 */
fun Spannable.repaintSpan(what: Any) {
  val start = getSpanStart(what)
  if (start < 0) return
  val target = (this as? InsertionOrderedSpannable)?.buffer ?: this
  target.setSpan(what, start, getSpanEnd(what), getSpanFlags(what))
}

fun AccessibleMarkdownTextView.setupAsMarkdownTextView() {
  setBackgroundColor(Color.TRANSPARENT)
  setSpannableFactory(NoCopySpannableFactory)
  includeFontPadding = false
  // The textBreakStrategy setter runs only when the prop is passed, while MeasurementStore
  // resolves a missing value to HIGH_QUALITY. Start from that value so both break lines alike.
  breakStrategy = BreakStrategyUtils.resolveBreakStrategy(null)
  BoundsForWidthUtils.applyTo(this)
  movementMethod = LinkLongPressMovementMethod.createInstance()
  setTextIsSelectable(true)
  customSelectionActionModeCallback = createSelectionActionModeCallback(this)
  // SmartSelectSprite crashes with "Center point is not inside any of the
  // rectangles!" when Layout.getSelection returns empty rects near an
  // ImageSpan (ReplacementSpan). NO_OP makes skipTextClassification() return
  // true, bypassing the entire SmartSelectSprite code path. Regular text
  // selection (long-press, handles, copy/paste) still works; only automatic
  // entity detection (phone numbers, addresses) is disabled.
  //
  // TODO: Add an Android-only `enableSmartTextSelection` prop that skips this
  // NO_OP override. This would let users who don't render images opt in to
  // entity detection. The prop should default to false and its docs should
  // warn that enabling it with markdown containing images will crash.
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
    setTextClassifier(TextClassifier.NO_OP)
  }
  isVerticalScrollBarEnabled = false
  isHorizontalScrollBarEnabled = false
  ViewCompat.setAccessibilityDelegate(this, accessibilityHelper)
}

fun AppCompatTextView.applySelectableState(selectable: Boolean) {
  if (isTextSelectable == selectable) return
  setTextIsSelectable(selectable)
  movementMethod = LinkLongPressMovementMethod.createInstance()
  if (!selectable && !isClickable) isClickable = true
}

// Editor disables selection if the first layout is built before the view is in a window, and
// doesn't re-check on attach. setMovementMethod does re-check, but only when given a different
// object, so this must be a new instance rather than the current one.
fun AppCompatTextView.refreshSelectionControllers() {
  if (isTextSelectable && layout != null) {
    movementMethod = LinkLongPressMovementMethod.createInstance()
  }
}
