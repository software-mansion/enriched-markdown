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
 * `SPAN_EXCLUSIVE_EXCLUSIVE` with a span priority just above the default.
 *
 * List item spans are set after the item's children, so at the default
 * priority they apply after inline spans such as `CodeSpan` and replace their
 * font and size. This priority applies them first, while staying below
 * [SPAN_FLAGS_CONTAINER_BACKGROUND] so a blockquote still draws its leading
 * margin before a list's.
 */
const val SPAN_FLAGS_LIST_ITEM =
  Spanned.SPAN_EXCLUSIVE_EXCLUSIVE or (1 shl Spanned.SPAN_PRIORITY_SHIFT)
