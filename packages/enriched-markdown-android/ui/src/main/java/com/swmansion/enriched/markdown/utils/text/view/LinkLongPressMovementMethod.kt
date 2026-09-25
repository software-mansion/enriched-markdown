package com.swmansion.enriched.markdown.utils.text.view

import android.os.Handler
import android.os.Looper
import android.text.Spannable
import android.text.method.ArrowKeyMovementMethod
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.TextView
import com.swmansion.enriched.markdown.spans.LinkSpan
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.SpoilerCapable
import kotlin.math.abs

/**
 * Movement method that adds link tap / long-press and spoiler tap handling on top of
 * [ArrowKeyMovementMethod], the method [setTextIsSelectable] installs.
 *
 * Must never mutate the buffer's Selection spans — the platform Editor
 * manages them during long-press gestures, and removing or overwriting
 * them mid-gesture crashes on some OEM skins.
 * See: https://github.com/software-mansion/enriched-markdown/issues/580
 */
class LinkLongPressMovementMethod : ArrowKeyMovementMethod() {
  private val handler = Handler(Looper.getMainLooper())
  private var longPressRunnable: Runnable? = null

  private var startX = 0f
  private var startY = 0f
  private var pressedLink: LinkSpan? = null
  private var pressedSpoiler: SpoilerSpan? = null

  var isLinkTouchActive: Boolean = false
    private set
  private var isTouchWithinTextBounds: Boolean = true

  override fun onTouchEvent(
    widget: TextView,
    buffer: Spannable,
    event: MotionEvent,
  ): Boolean {
    when (event.action) {
      MotionEvent.ACTION_DOWN -> {
        startX = event.x
        startY = event.y

        // A link under a concealed spoiler stays inert until the spoiler is revealed.
        pressedSpoiler = findConcealedSpoiler(widget, buffer, event)
        pressedLink = if (pressedSpoiler == null) findLinkSpan(widget, buffer, event) else null
        isLinkTouchActive = pressedLink != null
        isTouchWithinTextBounds = charOffsetAt(widget, event) != null
        pressedLink?.let { scheduleLongPress(widget, it) }
      }

      MotionEvent.ACTION_MOVE -> {
        val config = ViewConfiguration.get(widget.context)
        if (abs(event.x - startX) > config.scaledTouchSlop ||
          abs(event.y - startY) > config.scaledTouchSlop
        ) {
          cancelLongPress()
          isLinkTouchActive = false
          pressedLink = null
          pressedSpoiler = null
        }
      }

      MotionEvent.ACTION_UP -> {
        cancelLongPress()
        val tappedLink = pressedLink
        val tappedSpoiler = pressedSpoiler
        isLinkTouchActive = false
        pressedLink = null
        pressedSpoiler = null

        if (tappedSpoiler != null &&
          event.eventTime - event.downTime < ViewConfiguration.getLongPressTimeout() &&
          findConcealedSpoiler(widget, buffer, event) === tappedSpoiler
        ) {
          revealSpoiler(widget, buffer, tappedSpoiler)
          return true
        }

        // LinkSpan.onClick itself swallows the click that follows a completed
        // long-press (and resets its internal flag), so it is always invoked
        // for a tap that started and ended on the same link.
        if (tappedLink != null && findLinkSpan(widget, buffer, event) === tappedLink) {
          tappedLink.onClick(widget)
          return true
        }
      }

      MotionEvent.ACTION_CANCEL -> {
        cancelLongPress()
        isLinkTouchActive = false
        pressedLink = null
        pressedSpoiler = null
      }
    }

    if (!isTouchWithinTextBounds) {
      return false
    }

    return super.onTouchEvent(widget, buffer, event)
  }

  private fun scheduleLongPress(
    widget: TextView,
    span: LinkSpan,
  ) {
    cancelLongPress()

    longPressRunnable =
      Runnable {
        if (span.onLongClick(widget)) {
          widget.cancelLongPress()
        }
        longPressRunnable = null
      }.also {
        handler.postDelayed(it, ViewConfiguration.getLongPressTimeout().toLong())
      }
  }

  private fun cancelLongPress() {
    longPressRunnable?.let(handler::removeCallbacks)
    longPressRunnable = null
  }

  private fun charOffsetAt(
    widget: TextView,
    event: MotionEvent,
  ): Int? {
    val x = event.x - widget.totalPaddingLeft + widget.scrollX
    val y = event.y - widget.totalPaddingTop + widget.scrollY
    val layout = widget.layout ?: return null

    if (y < 0f || y > layout.height) {
      return null
    }

    val line = layout.getLineForVertical(y.toInt())

    if (x < layout.getLineLeft(line) || x > layout.getLineRight(line)) {
      return null
    }

    return layout.getOffsetForHorizontal(line, x)
  }

  private fun findLinkSpan(
    widget: TextView,
    buffer: Spannable,
    event: MotionEvent,
  ): LinkSpan? {
    val offset = charOffsetAt(widget, event) ?: return null
    return buffer.getSpans(offset, offset, LinkSpan::class.java).firstOrNull()
  }

  private fun findConcealedSpoiler(
    widget: TextView,
    buffer: Spannable,
    event: MotionEvent,
  ): SpoilerSpan? {
    if ((widget as? SpoilerCapable)?.spoilerOverlayDrawer == null) return null
    val offset = charOffsetAt(widget, event) ?: return null
    return buffer
      .getSpans(offset, offset, SpoilerSpan::class.java)
      .firstOrNull { !it.revealed && !it.revealing }
  }

  private fun revealSpoiler(
    widget: TextView,
    buffer: Spannable,
    tappedSpan: SpoilerSpan,
  ) {
    val drawer = (widget as? SpoilerCapable)?.spoilerOverlayDrawer ?: return
    val spans = expandContiguousSpoilers(buffer, tappedSpan)
    val remaining = intArrayOf(spans.size)

    for (span in spans) {
      drawer.revealSpan(span) {
        remaining[0]--
        if (remaining[0] <= 0) widget.invalidate()
      }
    }
    widget.invalidate()
  }

  private fun expandContiguousSpoilers(
    buffer: Spannable,
    seed: SpoilerSpan,
  ): List<SpoilerSpan> {
    val allSpans = buffer.getSpans(0, buffer.length, SpoilerSpan::class.java)
    if (allSpans.size <= 1) return listOf(seed)

    val result = mutableSetOf(seed)
    var rangeStart = buffer.getSpanStart(seed)
    var rangeEnd = buffer.getSpanEnd(seed)
    var changed = true
    while (changed) {
      changed = false
      for (span in allSpans) {
        if (span in result) continue
        val spanStart = buffer.getSpanStart(span)
        val spanEnd = buffer.getSpanEnd(span)
        if (spanEnd >= rangeStart && spanStart <= rangeEnd) {
          result.add(span)
          if (spanStart < rangeStart) rangeStart = spanStart
          if (spanEnd > rangeEnd) rangeEnd = spanEnd
          changed = true
        }
      }
    }
    return result.sortedBy { buffer.getSpanStart(it) }
  }

  companion object {
    @JvmStatic
    fun createInstance(): LinkLongPressMovementMethod = LinkLongPressMovementMethod()
  }
}
