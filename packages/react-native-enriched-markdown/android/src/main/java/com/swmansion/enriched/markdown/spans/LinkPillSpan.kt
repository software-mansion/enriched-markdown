package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.text.Spanned
import android.text.TextPaint
import android.text.TextUtils
import android.text.style.ReplacementSpan
import com.swmansion.enriched.markdown.styles.LinkVariantEntry
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/** Draws an atomic visual over the original link text, without changing stored characters. */
class LinkPillSpan(
  private val variant: LinkVariantEntry,
  private val typeface: android.graphics.Typeface,
  private val fontSize: Float,
  originalLinkText: String,
  context: Context,
) : ReplacementSpan() {
  private val label = (variant.label.ifEmpty { originalLinkText }).replace('\n', ' ').replace('\r', ' ')
  private var availableWidth = Float.MAX_VALUE
  private val icon = LinkPillIconCache.load(context, variant.iconUri)
  private val iconPaint =
    Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
    }

  val accessibilityText = if (label == originalLinkText) originalLinkText else "$label, $originalLinkText"

  init {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) contentDescription = accessibilityText
  }

  fun prepareForMeasurement(width: Int): Boolean {
    val next = width.coerceAtLeast(1).toFloat()
    if (availableWidth == next) return false
    availableWidth = next
    return true
  }

  private fun textPaint(paint: Paint) =
    TextPaint(paint).apply {
      typeface = this@LinkPillSpan.typeface
      textSize = fontSize
      color = variant.color
      bgColor = 0
      isUnderlineText = variant.underline
      isStrikeThruText = false
    }

  private fun width(paint: Paint): Float {
    val iconWidth = if (icon == null) 0f else fontSize + fontSize * 0.25f
    val natural = paint.measureText(label) + iconWidth + 2 * (variant.paddingHorizontal + variant.borderWidth)
    val limit = if (variant.maxWidth > 0) min(availableWidth, variant.maxWidth) else availableWidth
    return min(ceil(natural), limit).coerceAtLeast(1f)
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int {
    val labelPaint = textPaint(paint)
    val metrics = labelPaint.fontMetricsInt
    val inset = ceil(variant.paddingVertical + variant.borderWidth).toInt()
    fm?.let {
      it.ascent = min(it.ascent, metrics.ascent - inset)
      it.descent = max(it.descent, metrics.descent + inset)
      it.top = min(it.top, it.ascent)
      it.bottom = max(it.bottom, it.descent)
    }
    return ceil(width(labelPaint)).toInt()
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
    val labelPaint = textPaint(paint)
    val metrics = labelPaint.fontMetrics
    val inset = variant.paddingVertical + variant.borderWidth
    val rect = RectF(x, y + metrics.ascent - inset, x + width(labelPaint), y + metrics.descent + inset)
    val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = variant.backgroundColor }
    canvas.drawRoundRect(rect, variant.borderRadius, variant.borderRadius, fill)
    if (variant.borderWidth > 0) {
      fill.color = variant.borderColor
      fill.style = Paint.Style.STROKE
      fill.strokeWidth = variant.borderWidth
      val border = RectF(rect).apply { inset(variant.borderWidth / 2, variant.borderWidth / 2) }
      canvas.drawRoundRect(border, variant.borderRadius, variant.borderRadius, fill)
    }
    val save = canvas.save()
    canvas.clipRect(rect)
    var left = x + variant.paddingHorizontal + variant.borderWidth
    val right = rect.right - variant.paddingHorizontal - variant.borderWidth
    if (icon != null && right - left >= fontSize) {
      val iconTop = y + (metrics.ascent + metrics.descent - fontSize) / 2
      val scale = fontSize / max(icon.width, icon.height)
      val destination = RectF(left, iconTop, left + icon.width * scale, iconTop + icon.height * scale)
      destination.offset((fontSize - destination.width()) / 2, (fontSize - destination.height()) / 2)
      canvas.drawBitmap(icon, null, destination, iconPaint)
      left += fontSize + fontSize * 0.25f
    }
    val displayed = TextUtils.ellipsize(label, labelPaint, max(0f, right - left), TextUtils.TruncateAt.END)
    canvas.drawText(displayed.toString(), left, y.toFloat(), labelPaint)
    canvas.restoreToCount(save)
  }

  companion object {
    /** Called before both Fabric measurement and visible TextView layout, including table cells. */
    fun prepareForMeasurement(
      text: CharSequence?,
      width: Int,
    ): Boolean {
      val spanned = text as? Spanned ?: return false
      var changed = false
      spanned.getSpans(0, spanned.length, LinkPillSpan::class.java).forEach { pill ->
        val start = spanned.getSpanStart(pill)
        val end = spanned.getSpanEnd(pill)
        val margin =
          spanned
            .getSpans(start, end, android.text.style.LeadingMarginSpan::class.java)
            .sumOf { max(it.getLeadingMargin(true), it.getLeadingMargin(false)) }
        changed = pill.prepareForMeasurement(width - margin) || changed
      }
      return changed
    }
  }
}
