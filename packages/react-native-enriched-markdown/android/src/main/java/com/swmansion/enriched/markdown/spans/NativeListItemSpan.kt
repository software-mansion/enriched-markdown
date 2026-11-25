package com.swmansion.enriched.markdown.spans

import android.text.Spanned

/** Retains clipboard semantics when the list's native container owns indentation and markers. */
data class NativeListItemSpan(
  val marker: BaseListSpan,
)

internal fun innermostListSpan(
  text: Spanned,
  start: Int,
  end: Int,
): BaseListSpan? =
  (
    text.getSpans(start, end, BaseListSpan::class.java).asSequence() +
      text.getSpans(start, end, NativeListItemSpan::class.java).asSequence().map { it.marker }
  ).maxByOrNull { it.depth }
