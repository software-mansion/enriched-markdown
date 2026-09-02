package com.swmansion.enriched.markdown.accessibility

import android.graphics.Rect
import android.os.Bundle
import android.text.Spanned
import android.view.View
import android.view.ViewTreeObserver
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.core.view.accessibility.AccessibilityNodeInfoCompat
import androidx.customview.widget.ExploreByTouchHelper
import com.swmansion.enriched.markdown.spans.BaseListSpan
import com.swmansion.enriched.markdown.spans.HeadingSpan
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.spans.TaskListSpan

class MarkdownAccessibilityHelper(
  private val textView: TextView,
) : ExploreByTouchHelper(textView) {
  private var items: List<AccessibilityItem> = emptyList()
  private var needsRebuild = false
  private var lastLayoutHashCode = 0
  private var pendingLayoutListener: ViewTreeObserver.OnGlobalLayoutListener? = null

  data class AccessibilityItem(
    val id: Int,
    val text: String,
    /** Full character range — used for hit-testing so there are no gaps between items. */
    val start: Int,
    val end: Int,
    /** Trimmed character range — used for bounds calculation to avoid whitespace offsets. */
    val visibleStart: Int = start,
    val visibleEnd: Int = end,
    val headingLevel: Int = 0,
    val linkUrl: String? = null,
    val listInfo: ListItemInfo? = null,
    val imageAltText: String? = null,
  ) {
    val isHeading get() = headingLevel > 0
    val isLink get() = linkUrl != null
    val isListItem get() = listInfo != null
    val isImage get() = imageAltText != null
  }

  data class ListItemInfo(
    val isOrdered: Boolean,
    val itemNumber: Int,
    val depth: Int,
    val taskChecked: Boolean? = null,
  )

  private data class SpanRange(
    val start: Int,
    val end: Int,
    val headingLevel: Int = 0,
    val linkUrl: String? = null,
    val imageAltText: String? = null,
  )

  fun invalidateAccessibilityItems() {
    needsRebuild = true
    if (textView.layout != null) {
      rebuildIfNeeded()
      invalidateRoot()
    } else {
      schedulePostLayoutRebuild()
    }
  }

  private fun schedulePostLayoutRebuild() {
    if (pendingLayoutListener != null) return
    val observer = textView.viewTreeObserver
    if (!observer.isAlive) return
    val listener =
      ViewTreeObserver.OnGlobalLayoutListener {
        removePendingLayoutListener()
        if (needsRebuild) {
          rebuildIfNeeded()
          invalidateRoot()
        }
      }
    pendingLayoutListener = listener
    observer.addOnGlobalLayoutListener(listener)
  }

  /**
   * Drops the pending global-layout listener, if any is still registered.
   *
   * Must run while the view is attached: `textView.viewTreeObserver` returns
   * the window's observer only until detach, and the listener was merged into
   * it from the view's floating observer when the view attached.
   */
  fun cleanup() {
    removePendingLayoutListener()
  }

  private fun removePendingLayoutListener() {
    val listener = pendingLayoutListener ?: return
    pendingLayoutListener = null
    val observer = textView.viewTreeObserver
    if (observer.isAlive) {
      observer.removeOnGlobalLayoutListener(listener)
    }
  }

  /**
   * When virtual children exist, prevent the host TextView from appearing as a
   * standalone focusable element in TalkBack's swipe order. Without this,
   * `setTextIsSelectable(true)` keeps the view focusable and TalkBack reads
   * the entire text as one element before entering the virtual hierarchy.
   */
  private fun updateHostFocusability() {
    val hasVirtualChildren = items.isNotEmpty()
    ViewCompat.setScreenReaderFocusable(textView, !hasVirtualChildren)
    textView.importantForAccessibility =
      if (hasVirtualChildren) View.IMPORTANT_FOR_ACCESSIBILITY_YES else View.IMPORTANT_FOR_ACCESSIBILITY_AUTO
  }

  private fun rebuildIfNeeded() {
    val layout = textView.layout ?: return
    if (needsRebuild || lastLayoutHashCode != layout.hashCode()) {
      items = buildItems()
      needsRebuild = false
      lastLayoutHashCode = layout.hashCode()
      updateHostFocusability()
    }
  }

  private fun buildItems(): List<AccessibilityItem> {
    val spanned = textView.text as? Spanned ?: return emptyList()
    if (spanned.isEmpty()) return emptyList()

    val text = spanned.toString()
    val result = mutableListOf<AccessibilityItem>()
    var nextId = 0
    val semanticSpans = collectSemanticSpans(spanned)

    var paraStart = 0
    while (paraStart < text.length) {
      val newlineIdx = text.indexOf('\n', paraStart)
      val paraEnd = if (newlineIdx == -1) text.length else newlineIdx + 1
      val trimmed = text.substring(paraStart, paraEnd).trim()

      if (trimmed.isNotEmpty()) {
        val spansInParagraph = semanticSpans.filter { it.start < paraEnd && it.end > paraStart }

        if (spansInParagraph.isEmpty()) {
          result.add(
            createTextItem(nextId++, trimmed, paraStart, paraEnd, text, spanned),
          )
        } else {
          nextId = addSegmentedItems(result, spanned, text, paraStart, paraEnd, spansInParagraph, nextId)
        }
      }
      paraStart = paraEnd
    }

    return result.ifEmpty { listOf(AccessibilityItem(0, text.trim(), 0, spanned.length)) }
  }

  private fun collectSemanticSpans(spanned: Spanned): List<SpanRange> =
    (
      spanned.getSpans(0, spanned.length, HeadingSpan::class.java).map {
        SpanRange(spanned.getSpanStart(it), spanned.getSpanEnd(it), headingLevel = it.level)
      } +
        spanned.getSpans(0, spanned.length, LinkSpan::class.java).map {
          SpanRange(spanned.getSpanStart(it), spanned.getSpanEnd(it), linkUrl = it.url)
        } +
        spanned.getSpans(0, spanned.length, ImageSpan::class.java).map {
          SpanRange(spanned.getSpanStart(it), spanned.getSpanEnd(it), imageAltText = it.altText)
        }
    ).sortedBy { it.start }

  private fun addSegmentedItems(
    items: MutableList<AccessibilityItem>,
    spanned: Spanned,
    text: String,
    paraStart: Int,
    paraEnd: Int,
    spans: List<SpanRange>,
    startId: Int,
  ): Int {
    var nextId = startId
    var segmentPos = paraStart

    for (span in spans) {
      if (span.start < segmentPos) continue

      // Text before the span
      if (segmentPos < span.start) {
        val beforeText = text.substring(segmentPos, span.start).trim()
        if (beforeText.isNotEmpty() && beforeText.any { it.isLetterOrDigit() }) {
          items.add(createTextItem(nextId++, beforeText, segmentPos, span.start, text, spanned))
        }
      }

      // The semantic span itself
      val content = span.imageAltText?.ifEmpty { "Image" } ?: spanned.substring(span.start, span.end).trim()
      if (content.isNotEmpty()) {
        items.add(createSpanItem(nextId++, content, span, spanned))
      }
      segmentPos = span.end
    }

    // Text after the last span
    if (segmentPos < paraEnd) {
      val afterText = text.substring(segmentPos, paraEnd).trim()
      if (afterText.isNotEmpty() && afterText.any { it.isLetterOrDigit() }) {
        items.add(createTextItem(nextId++, afterText, segmentPos, paraEnd, text, spanned))
      }
    }

    return nextId
  }

  private fun createTextItem(
    id: Int,
    label: String,
    start: Int,
    end: Int,
    text: String,
    spanned: Spanned,
  ) = AccessibilityItem(
    id = id,
    text = label,
    start = start,
    end = end,
    visibleStart = text.findFirstNonWhitespace(start, end),
    visibleEnd = text.findLastNonWhitespace(start, end),
    listInfo = getListInfoAt(spanned, start, requireStart = true),
  )

  private fun createSpanItem(
    id: Int,
    content: String,
    span: SpanRange,
    spanned: Spanned,
  ): AccessibilityItem {
    val listContext =
      if (span.headingLevel > 0 || span.imageAltText != null) {
        null
      } else {
        getListInfoAt(spanned, span.start, requireStart = span.linkUrl == null)
      }
    return AccessibilityItem(
      id = id,
      text = content,
      start = span.start,
      end = span.end,
      headingLevel = span.headingLevel,
      linkUrl = span.linkUrl,
      listInfo = listContext,
      imageAltText = span.imageAltText,
    )
  }

  override fun getVirtualViewAt(
    x: Float,
    y: Float,
  ): Int {
    rebuildIfNeeded()
    if (items.isEmpty()) return HOST_ID

    val offset = getCharOffsetAt(x, y)

    val exact =
      items
        .filter { offset in it.start until it.end }
        .minByOrNull { it.hitTestPriority }
    if (exact != null) return exact.id

    return items.minByOrNull { it.distanceTo(offset) }?.id ?: HOST_ID
  }

  override fun getVisibleVirtualViews(ids: MutableList<Int>) {
    rebuildIfNeeded()
    items.forEach { ids.add(it.id) }
  }

  override fun onPopulateNodeForHost(host: AccessibilityNodeInfoCompat) {
    super.onPopulateNodeForHost(host)
    rebuildIfNeeded()
    if (items.isNotEmpty()) {
      host.isScreenReaderFocusable = false
      host.isFocusable = false
      // Prevent TalkBack from reading the full text when swiping onto the host.
      // Without this, the host node retains the TextView's text and TalkBack
      // announces it as a single element before entering the virtual children.
      host.text = null
      host.contentDescription = null
    }
  }

  override fun onPopulateNodeForVirtualView(
    id: Int,
    node: AccessibilityNodeInfoCompat,
  ) {
    val item = items.getOrNull(id)
    if (item == null) {
      node.contentDescription = ""
      node.setBoundsInParent(Rect())
      return
    }
    node.apply {
      text = item.text
      contentDescription = item.text
      isFocusable = true
      isScreenReaderFocusable = true
      setBoundsInParent(boundsForItem(item))
      applySemantics(item)
    }
  }

  override fun onPerformActionForVirtualView(
    id: Int,
    action: Int,
    args: Bundle?,
  ): Boolean {
    val item = items.getOrNull(id) ?: return false
    if (action == AccessibilityNodeInfoCompat.ACTION_CLICK && item.isLink) {
      val spanned = textView.text as? Spanned ?: return false
      val linkSpan = spanned.getSpans(item.start, item.end, LinkSpan::class.java).firstOrNull() ?: return false
      linkSpan.onClick(textView)
      return true
    }
    return false
  }

  private fun AccessibilityNodeInfoCompat.applySemantics(item: AccessibilityItem) {
    item.listInfo?.let { info ->
      setCollectionItemInfo(
        AccessibilityNodeInfoCompat.CollectionItemInfoCompat.obtain(info.itemNumber - 1, 1, 0, 1, false, false),
      )
    }

    when {
      item.isHeading -> {
        isHeading = true
        contentDescription = "${item.text}, heading level ${item.headingLevel}"
      }

      item.isImage -> {
        roleDescription = "image"
      }

      item.isLink -> {
        isClickable = true
        addAction(AccessibilityNodeInfoCompat.AccessibilityActionCompat.ACTION_CLICK)
        roleDescription = item.listInfo?.let { "link, ${it.listAnnouncement}" } ?: "link"
      }

      item.isListItem -> {
        roleDescription = item.listInfo!!.listAnnouncement
      }
    }
  }

  private val ListItemInfo.listAnnouncement: String
    get() {
      val prefix = if (depth > 0) "nested " else ""
      taskChecked?.let { checked ->
        return "${prefix}task, ${if (checked) "checked" else "not checked"}"
      }
      return if (isOrdered) "${prefix}list item $itemNumber" else "${prefix}bullet point"
    }

  private fun boundsForItem(item: AccessibilityItem): Rect {
    val layout = textView.layout ?: return Rect()
    val vs = item.visibleStart
    val ve = item.visibleEnd

    val startLine = layout.getLineForOffset(vs)
    val endLine = layout.getLineForOffset(maxOf(vs, ve - 1))

    if (startLine == endLine) {
      return singleLineBounds(vs, ve, startLine)
    }

    return multiLineBounds(vs, startLine, endLine)
  }

  private fun singleLineBounds(
    start: Int,
    end: Int,
    line: Int,
  ): Rect {
    val layout = textView.layout
    val left = layout.getPrimaryHorizontal(start).toInt() + textView.paddingLeft
    val rawRight = layout.getPrimaryHorizontal(end).toInt() + textView.paddingLeft
    val right = if (rawRight <= left) layout.getLineRight(line).toInt() + textView.paddingLeft else rawRight

    return Rect(
      left,
      layout.getLineTop(line) + textView.paddingTop,
      right,
      layout.getLineBottom(line) + textView.paddingTop,
    )
  }

  private fun multiLineBounds(
    visibleStart: Int,
    startLine: Int,
    endLine: Int,
  ): Rect {
    val layout = textView.layout
    val padLeft = textView.paddingLeft

    val firstLineLeft = layout.getPrimaryHorizontal(visibleStart).toInt() + padLeft
    val firstLineRight = layout.getLineRight(startLine).toInt() + padLeft

    var minLeft = firstLineLeft
    var maxRight = firstLineRight
    for (line in (startLine + 1)..endLine) {
      minLeft = minOf(minLeft, layout.getLineLeft(line).toInt() + padLeft)
      maxRight = maxOf(maxRight, layout.getLineRight(line).toInt() + padLeft)
    }

    return Rect(
      minOf(firstLineLeft, minLeft),
      layout.getLineTop(startLine) + textView.paddingTop,
      maxRight,
      layout.getLineBottom(endLine) + textView.paddingTop,
    )
  }

  private fun getCharOffsetAt(
    x: Float,
    y: Float,
  ): Int {
    val layout = textView.layout ?: return 0
    val line = layout.getLineForVertical(y.toInt()).coerceIn(0, layout.lineCount - 1)
    return layout.getOffsetForHorizontal(line, x)
  }

  private val AccessibilityItem.hitTestPriority: Int
    get() =
      when {
        isLink -> 0
        isImage -> 1
        isHeading -> 2
        isListItem -> 3
        else -> 4
      }

  private fun AccessibilityItem.distanceTo(offset: Int): Int =
    when {
      offset < start -> start - offset
      offset >= end -> offset - end + 1
      else -> 0
    }

  private fun getListInfoAt(
    spanned: Spanned,
    position: Int,
    requireStart: Boolean,
  ): ListItemInfo? {
    val deepest =
      spanned
        .getSpans(position, position + 1, BaseListSpan::class.java)
        .maxByOrNull { it.depth } ?: return null

    if (requireStart) {
      val spanStart = spanned.getSpanStart(deepest)
      val firstChar =
        (spanStart until minOf(spanStart + 10, spanned.length))
          .firstOrNull { !spanned[it].isWhitespace() } ?: spanStart
      if (position > firstChar + 1) return null
    }

    return ListItemInfo(
      isOrdered = deepest is OrderedListSpan,
      itemNumber = (deepest as? OrderedListSpan)?.itemNumber ?: 0,
      depth = deepest.depth,
      taskChecked = (deepest as? TaskListSpan)?.isChecked,
    )
  }
}

private fun String.findFirstNonWhitespace(
  from: Int,
  to: Int,
): Int {
  for (i in from until to) {
    if (!this[i].isWhitespace()) return i
  }
  return from
}

private fun String.findLastNonWhitespace(
  from: Int,
  to: Int,
): Int {
  for (i in (to - 1) downTo from) {
    if (!this[i].isWhitespace()) return i + 1
  }
  return to
}
