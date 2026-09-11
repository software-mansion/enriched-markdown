package com.swmansion.enriched.markdown.spans

import android.graphics.Paint
import android.text.style.LineHeightSpan
import com.swmansion.enriched.markdown.styles.BlockquoteStyle
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.roundToInt

/**
 * Reserves the band an admonition header (tinted octicon + bold title) is painted into.
 *
 * The React Native renderer gives each top-level admonition its own view and reserves the header
 * by enlarging that view's top padding. This package renders a whole document into one TextView,
 * so there is no view to pad: the header gets a standalone spacer line at the very start of the
 * quote instead, and this span fixes that line's height to exactly the space the header needs.
 *
 * A spacer line is used rather than growing the first content line's ascent for the same reason
 * `BlockquoteRenderer` uses one for the quote's top padding: StaticLayout reuses one
 * FontMetricsInt across a paragraph's soft-wrapped lines, so inflated first-line metrics leak
 * into the wrapped continuation lines. Setting absolute metrics on a line of its own is immune to
 * that reuse.
 *
 * The header itself is painted by [BlockquoteSpan], which already draws every level of the box
 * from the view's content edge and so knows the correct left inset and layout direction. This span
 * only reserves the space, and marks the spacer character so the copy/HTML/accessibility paths can
 * recognize it.
 */
class AdmonitionHeaderSpan(
  /** Admonition type, one of [AdmonitionIcons.TYPES]. */
  val type: String,
  style: BlockquoteStyle,
) : LineHeightSpan {
  /** Height of the icon + title row itself. */
  val contentHeight: Float = admonitionHeaderContentHeight(style)

  /** Total height of the spacer line: the icon + title row plus the gap down to the body. */
  val reservedHeight: Float = admonitionHeaderReservedHeight(style)

  val title: String get() = AdmonitionIcons.title(type)

  override fun chooseHeight(
    text: CharSequence,
    startLine: Int,
    endLine: Int,
    spanstartv: Int,
    v: Int,
    fm: Paint.FontMetricsInt,
  ) {
    val height = ceil(reservedHeight).toInt()
    fm.top = 0
    fm.ascent = 0
    fm.descent = height
    fm.bottom = height
  }

  companion object {
    /**
     * Height of the header band (icon + title row).
     *
     * Kept identical to `BlockquoteContainerView.admonitionHeaderContentHeight` in the React
     * Native package so both renderers reserve the same space for the same font size.
     */
    fun admonitionHeaderContentHeight(style: BlockquoteStyle): Float = ceil(max(ceil(style.fontSize), style.fontSize * 1.35f))

    /** Vertical space the header adds above the body: the band plus the gap below it. */
    fun admonitionHeaderReservedHeight(style: BlockquoteStyle): Float =
      admonitionHeaderContentHeight(style) + (style.fontSize * 0.4f).roundToInt()
  }
}
