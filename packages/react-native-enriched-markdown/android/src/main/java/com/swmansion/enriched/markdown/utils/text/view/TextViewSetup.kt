package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.Color
import android.os.Build
import android.text.DynamicLayout
import android.text.Editable
import android.text.GetChars
import android.text.NoCopySpan
import android.text.SpanWatcher
import android.text.Spannable
import android.text.SpannableString
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.TextWatcher
import android.text.style.UpdateLayout
import android.view.textclassifier.TextClassifier
import android.widget.TextView
import androidx.appcompat.widget.AppCompatTextView
import androidx.core.view.ViewCompat
import com.swmansion.enriched.markdown.accessibility.AccessibleMarkdownTextView
import com.swmansion.enriched.markdown.segments.replaceTail
import com.swmansion.enriched.markdown.utils.common.BoundsForWidthUtils
import com.swmansion.enriched.markdown.utils.common.BreakStrategyUtils
import java.util.IdentityHashMap

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

  // Watchers set on this text, by the proxy that stands in for each in the buffer.
  private val watcherProxies = IdentityHashMap<Any, WatcherProxy>()

  // Set while [repaintSpan] re-sets a span: the watchers hear it from the buffer then, which the
  // view draws again from and DynamicLayout ignores, so nothing is laid out again.
  var repainting = false

  /**
   * Replaces the text from [start] on with [tail] as one change, told to the layouts, which reflow
   * once where the buffer would tell them of every span it copies, and to TextView's own watcher,
   * so its Editor's word iterator and touch offsets follow the text: a word selection on a stale
   * one throws. That watcher hears only onTextChanged; afterTextChanged would copy the text for
   * autofill and content capture. The view keeps its scroll ([AccessibleMarkdownTextView]) and
   * invalidates itself. False, with the text unchanged, when [hasLayout] but no layout watches the
   * text: none would reflow.
   */
  fun replaceTail(
    start: Int,
    tail: Spanned,
    hasLayout: Boolean,
  ): Boolean {
    val before = buffer.length - start
    val proxies = buffer.getSpans(0, buffer.length, WatcherProxy::class.java)
    val layouts = watchersOf(proxies, DynamicLayout::class.java)
    if (hasLayout && layouts.isEmpty()) return false
    layouts.forEach { it.beforeTextChanged(this, start, before, tail.length) }
    proxies.forEach { it.muted = true }
    try {
      buffer.replaceTail(start, tail)
    } finally {
      proxies.forEach { it.muted = false }
    }
    layouts.forEach { it.onTextChanged(this, start, before, tail.length) }
    layouts.forEach { it.afterTextChanged(buffer) }
    watchersOf(proxies, TextView::class.java).forEach { it.onTextChanged(this, start, before, tail.length) }
    return true
  }

  // The text watchers an instance of [owner]'s inner class set: DynamicLayout's, or TextView's.
  private fun watchersOf(
    proxies: Array<WatcherProxy>,
    owner: Class<*>,
  ) = proxies.mapNotNull { proxy -> (proxy.watcher as? TextWatcher)?.takeIf { it.javaClass.enclosingClass == owner } }

  override fun <T : Any?> getSpans(
    start: Int,
    end: Int,
    type: Class<T>,
  ): Array<T> {
    val spans = buffer.getSpans(start, end, type)
    // Layout asks for styles, never watchers: only a query a watcher could answer is mapped.
    if (watcherProxies.isEmpty() || (!type.isAssignableFrom(WatcherProxy::class.java) && !isWatcherType(type))) return spans
    val watchers = buffer.getSpans(start, end, WatcherProxy::class.java).map { it.watcher }.filter { type.isInstance(it) }
    val result = spans.filterNot { it is WatcherProxy } + watchers

    @Suppress("UNCHECKED_CAST")
    val typed =
      java.lang.reflect.Array
        .newInstance(type, result.size) as Array<T>
    result.forEachIndexed { index, span -> typed[index] = type.cast(span) }
    return typed
  }

  // A watcher type the proxies don't implement (e.g. TextView's ChangeWatcher class).
  private fun isWatcherType(type: Class<*>) = watcherProxies.keys.any { type.isInstance(it) }

  override fun getSpanStart(tag: Any): Int = buffer.getSpanStart(watcherProxies[tag] ?: tag)

  override fun getSpanEnd(tag: Any): Int = buffer.getSpanEnd(watcherProxies[tag] ?: tag)

  override fun getSpanFlags(tag: Any): Int = buffer.getSpanFlags(watcherProxies[tag] ?: tag)

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
    val span = if (what is TextWatcher || what is SpanWatcher) watcherProxies.getOrPut(what) { WatcherProxy(what, this) } else what
    buffer.setSpan(span, start, end, flags)
    if (what !is UpdateLayout || oldStart < 0) return
    buffer
      .getSpans(minOf(oldStart, start), minOf(maxOf(oldEnd, end), length), SpanWatcher::class.java)
      .forEach { it.onSpanChanged(this, what, oldStart, oldEnd, start, end) }
  }

  override fun removeSpan(what: Any) = buffer.removeSpan(watcherProxies.remove(what) ?: what)

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
  if (this !is InsertionOrderedSpannable) {
    setSpan(what, start, getSpanEnd(what), getSpanFlags(what))
    return
  }
  repainting = true
  try {
    buffer.setSpan(what, start, getSpanEnd(what), getSpanFlags(what))
  } finally {
    repainting = false
  }
}

/**
 * Stands in the buffer for a watcher set on an [InsertionOrderedSpannable], and reports that
 * text, not the buffer, as the one that changed. DynamicLayout ignores changes to any text but
 * the one it lays out, so a patch to the buffer ([replaceAdoptedTextTail]) reflows the lines
 * only through this.
 */
private class WatcherProxy(
  val watcher: Any,
  private val text: Spannable,
) : TextWatcher,
  SpanWatcher,
  NoCopySpan {
  // Set while [InsertionOrderedSpannable.replaceTail] tells the watcher of the change itself.
  var muted = false

  override fun beforeTextChanged(
    s: CharSequence,
    start: Int,
    count: Int,
    after: Int,
  ) {
    if (!muted) (watcher as? TextWatcher)?.beforeTextChanged(text, start, count, after)
  }

  override fun onTextChanged(
    s: CharSequence,
    start: Int,
    before: Int,
    count: Int,
  ) {
    if (!muted) (watcher as? TextWatcher)?.onTextChanged(text, start, before, count)
  }

  override fun afterTextChanged(s: Editable) {
    if (!muted) (watcher as? TextWatcher)?.afterTextChanged(s)
  }

  override fun onSpanAdded(
    s: Spannable,
    what: Any,
    start: Int,
    end: Int,
  ) {
    if (!muted) (watcher as? SpanWatcher)?.onSpanAdded(text, unwrap(what), start, end)
  }

  override fun onSpanRemoved(
    s: Spannable,
    what: Any,
    start: Int,
    end: Int,
  ) {
    if (!muted) (watcher as? SpanWatcher)?.onSpanRemoved(text, unwrap(what), start, end)
  }

  override fun onSpanChanged(
    s: Spannable,
    what: Any,
    ostart: Int,
    oend: Int,
    nstart: Int,
    nend: Int,
  ) {
    if (muted) return
    val source = if ((text as? InsertionOrderedSpannable)?.repainting == true) s else text
    (watcher as? SpanWatcher)?.onSpanChanged(source, unwrap(what), ostart, oend, nstart, nend)
  }

  private fun unwrap(what: Any): Any = (what as? WatcherProxy)?.watcher ?: what
}

/** Whether [text] is a buffer a markdown text view adopted, which patches edit in place. */
fun isAdoptedText(text: CharSequence?): Boolean = text is InsertionOrderedSpannable

/**
 * Replaces [text] from [start] on with [tail] in place, as one change, when [text] is a buffer a
 * markdown text view adopted and, if the view [hasLayout], that layout watches it; false otherwise.
 */
fun replaceAdoptedTextTail(
  text: CharSequence?,
  start: Int,
  tail: Spanned,
  hasLayout: Boolean,
): Boolean = text is InsertionOrderedSpannable && start <= text.length && text.replaceTail(start, tail, hasLayout)

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
