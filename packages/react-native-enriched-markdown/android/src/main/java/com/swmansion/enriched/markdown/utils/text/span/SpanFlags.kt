package com.swmansion.enriched.markdown.utils.text.span

import android.text.SpannableString
import android.text.Spanned

const val SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE = SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE

/**
 * `SPAN_EXCLUSIVE_EXCLUSIVE` with the maximum span priority.
 *
 * Higher-priority spans are iterated — and therefore drawn — first, so any
 * lower-priority span on the same line ends up painted *on top* visually.
 * Use this for full-width container backgrounds (e.g. blockquote fill in
 * [BlockquoteSpan]) that must sit under inline pill/chip backgrounds.
 */
const val SPAN_FLAGS_CONTAINER_BACKGROUND =
  Spanned.SPAN_EXCLUSIVE_EXCLUSIVE or Spanned.SPAN_PRIORITY

/**
 * `SPAN_EXCLUSIVE_EXCLUSIVE` with the maximum span priority, for a block-wide
 * LineHeightSpan (e.g. a blockquote's uniform line height) that must be iterated
 * BEFORE the per-block [MarginBottomSpan]s it overlaps. LineHeightSpans are
 * applied in iteration order and higher priority iterates first, so this span
 * sets the base line height and the lower-priority margin span then adds its gap
 * on top instead of being normalized away. Without it a line-height pass applied
 * after the margins (e.g. in BlockquoteTextRenderer.postProcess) would erase them
 * and clip the first line's ascent.
 */
const val SPAN_FLAGS_LINE_HEIGHT_PRIORITY =
  Spanned.SPAN_EXCLUSIVE_EXCLUSIVE or Spanned.SPAN_PRIORITY
