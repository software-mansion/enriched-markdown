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
