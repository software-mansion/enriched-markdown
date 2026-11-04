package com.swmansion.enriched.markdown.utils.text.span

import android.text.SpannableString
import android.text.Spanned

const val SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE = SpannableString.SPAN_EXCLUSIVE_EXCLUSIVE

/**
 * `SPAN_EXCLUSIVE_EXCLUSIVE` with the maximum span priority.
 *
 * Higher-priority spans are iterated — and therefore applied and drawn — first,
 * so lower-priority spans over the same range override them. Use this for a
 * block span set after its children that must not override the inline spans
 * inside it (e.g. [HeadingSpan]), or for a container background that must sit
 * under inline pill/chip backgrounds (e.g. [BlockquoteSpan]).
 */
const val SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE_PRIORITY =
  Spanned.SPAN_EXCLUSIVE_EXCLUSIVE or Spanned.SPAN_PRIORITY

/**
 * `SPAN_EXCLUSIVE_EXCLUSIVE` with a span priority just above the default.
 *
 * List item spans are set after the item's children, so at the default
 * priority they apply after inline spans such as `CodeSpan` and replace their
 * font and size. This priority applies them first, while staying below
 * [SPAN_FLAGS_EXCLUSIVE_EXCLUSIVE_PRIORITY] so a blockquote still draws its
 * leading margin before a list's.
 */
const val SPAN_FLAGS_LIST_ITEM =
  Spanned.SPAN_EXCLUSIVE_EXCLUSIVE or (1 shl Spanned.SPAN_PRIORITY_SHIFT)

/**
 * `SPAN_EXCLUSIVE_EXCLUSIVE` with a span priority just above [SPAN_FLAGS_LIST_ITEM].
 *
 * For `ListMarkerAnchorSpan`: it draws a list marker on a line its item's own
 * spans do not own, from the `x` Layout hands it. Ordered ahead of every list
 * span and code block span on the line, that `x` is past the enclosing
 * blockquotes only, the same origin the item's own span draws from.
 */
const val SPAN_FLAGS_LIST_MARKER_ANCHOR =
  Spanned.SPAN_EXCLUSIVE_EXCLUSIVE or (2 shl Spanned.SPAN_PRIORITY_SHIFT)
