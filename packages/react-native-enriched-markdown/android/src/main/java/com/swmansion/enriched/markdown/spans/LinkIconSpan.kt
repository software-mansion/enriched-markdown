package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Looper
import android.text.Spannable
import android.text.Spanned
import android.text.TextPaint
import android.text.style.CharacterStyle
import android.text.style.MetricAffectingSpan
import android.text.style.ReplacementSpan
import android.view.View
import android.widget.TextView
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.spoiler.spoilerTextAlpha
import com.swmansion.enriched.markdown.styles.LinkInlineIconStyle
import com.swmansion.enriched.markdown.utils.common.findEnrichedMarkdownAncestor
import com.swmansion.enriched.markdown.utils.text.view.repaintSpan
import java.lang.ref.WeakReference
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Draws a link variant's inline icon in front of the link's first character, which it
 * covers and draws itself. Nothing is inserted into the text, so copy, export and
 * accessibility read the link as it is, and the rest of the link wraps as ordinary text.
 */
class LinkIconSpan(
  private val style: LinkInlineIconStyle,
  private val link: LinkSpan,
  private val fontSize: Float,
  context: Context,
  requestHeaders: Map<String, String> = emptyMap(),
) : ReplacementSpan() {
  @Volatile
  private var icon: Bitmap? = null

  // A remote icon keeps its slot while it loads, so its arrival needs a redraw, never a
  // relayout. A failed load gives the slot up, which reflows the text and re-measures.
  @Volatile
  private var reservesIconSlot: Boolean
  private val views = ArrayList<WeakReference<View>>()
  private var onSlotReleased: (() -> Unit)? = null

  init {
    val iconUri = style.iconUri
    if (LinkPillIconCache.isRemote(iconUri)) {
      reservesIconSlot = !LinkPillIconCache.hasFailedRecently(iconUri, requestHeaders)
      if (reservesIconSlot) {
        LinkPillIconCache
          .loadRemote(context, iconUri, requestHeaders) { loaded ->
            if (loaded == null) {
              releaseIconSlot()
            } else {
              icon = loaded
              withHosts { hosts -> hosts.forEach { repaintIn(it) } }
            }
          }?.let { icon = it }
      }
    } else {
      icon = LinkPillIconCache.load(context, iconUri)
      reservesIconSlot = icon != null
    }
  }

  private val slotWidth: Float
    get() = if (reservesIconSlot) fontSize * ICON_SLOT_RATIO else 0f

  // A replacement span's paint gets the metric-affecting spans but none of the draw-only ones
  // (the link's color, a strikethrough), so the covered word applies those at its start itself.
  private fun TextPaint.applyCharacterStyles(
    source: Paint,
    text: CharSequence,
    start: Int,
  ): TextPaint {
    set(source)
    val spanned = text as? Spanned
    if (spanned == null) {
      link.updateDrawState(this)
    } else {
      for (span in spanned.getSpans(start, start + 1, CharacterStyle::class.java)) {
        // The spoiler hides text through the paint; draw fades the whole span instead.
        if (span is MetricAffectingSpan || span is SpoilerSpan) continue
        if (spanned.getSpanStart(span) <= start) span.updateDrawState(this)
      }
    }
    bgColor = 0
    return this
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    // Measurement can run off the main thread, so it keeps its own paint. The metric-affecting
    // spans, the link font among them, are already applied to [paint].
    val labelPaint = TextPaint().apply { set(paint) }
    fm?.let {
      val metrics = labelPaint.fontMetricsInt
      it.ascent = min(it.ascent, metrics.ascent)
      it.descent = max(it.descent, metrics.descent)
      it.top = min(it.top, metrics.top)
      it.bottom = max(it.bottom, metrics.bottom)
    }
    return ceil(slotWidth + labelPaint.measureText(text, start, end)).toInt()
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    // A spoiler conceals text through the paint, which a replacement span's paint never gets.
    val visibility = (text as? Spanned)?.spoilerTextAlpha(start, end) ?: 1f
    if (visibility <= 0f) return
    val labelPaint = drawPaint.applyCharacterStyles(paint, text, start)
    if (visibility < 1f) labelPaint.alpha = (labelPaint.alpha * visibility).roundToInt()
    val metrics = drawMetrics.also { labelPaint.getFontMetrics(it) }
    val slot = slotWidth
    icon?.takeIf { slot > 0f }?.let {
      val iconTop = y + (metrics.ascent + metrics.descent - fontSize) / 2
      val scale = fontSize / max(it.width, it.height)
      rect.set(x, iconTop, x + it.width * scale, iconTop + it.height * scale)
      rect.offset((fontSize - rect.width()) / 2, (fontSize - rect.height()) / 2)
      iconPaint.colorFilter = style.iconTint
      iconPaint.alpha = (255 * visibility).roundToInt()
      canvas.drawBitmap(it, null, rect, iconPaint)
    }
    canvas.drawText(text, start, end, x + slot, y.toFloat(), labelPaint)
  }

  /** Lets an icon that arrives after layout redraw [view], and a failed one reflow it. */
  fun registerView(
    view: View,
    onSlotReleased: (() -> Unit)? = null,
  ) {
    if (!reservesIconSlot || icon != null) return
    this.onSlotReleased = onSlotReleased
    synchronized(views) {
      views.removeAll { it.get() == null }
      if (views.none { it.get() === view }) views.add(WeakReference(view))
    }
  }

  private fun releaseIconSlot() {
    reservesIconSlot = false
    withHosts { hosts ->
      val host = hosts.firstOrNull { reflowIn(it) } ?: return@withHosts
      onSlotReleased?.let {
        it()
        return@withHosts
      }
      if (host is EnrichedMarkdownText) {
        host.layoutManager.invalidateLayout()
      } else {
        host.findEnrichedMarkdownAncestor()?.onImageLayoutChanged()
      }
    }
  }

  private fun withHosts(action: (List<View>) -> Unit) {
    val hosts = synchronized(views) { views.mapNotNull { it.get() }.also { views.clear() } }
    if (hosts.isEmpty()) return
    if (Looper.myLooper() == Looper.getMainLooper()) action(hosts) else hosts.first().post { action(hosts) }
  }

  /** Re-setting the span makes a TextView lay it out again. False when [view] no longer shows it. */
  private fun reflowIn(view: View): Boolean {
    TextBackgroundDrawer.noteReflow()
    val text = (view as? TextView)?.text as? Spannable
    val start = text?.getSpanStart(this) ?: -1
    if (text != null && start >= 0) {
      text.setSpan(this, start, text.getSpanEnd(this), text.getSpanFlags(this))
      return true
    }
    view.invalidate()
    return false
  }

  private fun repaintIn(view: View) {
    ((view as? TextView)?.text as? Spannable)?.repaintSpan(this) ?: view.invalidate()
  }

  companion object {
    // The icon is a square of the font size; the slot adds a quarter of it as the gap to the text.
    private const val ICON_SLOT_RATIO = 1.25f

    // Drawing happens on the main thread only, so all icons share these scratch objects.
    private val iconPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val drawPaint = TextPaint()
    private val drawMetrics = Paint.FontMetrics()
    private val rect = RectF()

    fun registerView(
      text: CharSequence?,
      view: View,
      onSlotReleased: (() -> Unit)? = null,
    ) {
      val spanned = text as? Spanned ?: return
      spanned.getSpans(0, spanned.length, LinkIconSpan::class.java).forEach { it.registerView(view, onSlotReleased) }
    }
  }
}

/**
 * Measures a link that wraps as text with the font it draws with. [LinkSpan] sets that
 * font only when drawing, which is too late for line breaking.
 */
class LinkFontSpan(
  private val link: LinkSpan,
) : MetricAffectingSpan() {
  override fun updateMeasureState(textPaint: TextPaint) = link.applyLinkFont(textPaint)

  override fun updateDrawState(textPaint: TextPaint) = link.applyLinkFont(textPaint)
}
