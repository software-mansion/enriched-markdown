package com.swmansion.enriched.markdown.accessibility

import android.text.Spanned

/** A replaced span TalkBack announces as its own element, labelled from the current [AccessibilityLabels]. */
interface SpokenSpan {
  fun accessibilityLabel(labels: AccessibilityLabels): String
}

internal fun Spanned.spokenText(
  start: Int,
  end: Int,
  labels: AccessibilityLabels,
): String {
  val text = StringBuilder()
  var pos = start
  for (spoken in getSpans(start, end, SpokenSpan::class.java).sortedBy { getSpanStart(it) }) {
    val spokenStart = getSpanStart(spoken)
    if (spokenStart < pos) continue
    text.append(this, pos, spokenStart).append(spoken.accessibilityLabel(labels))
    pos = minOf(getSpanEnd(spoken), end)
  }
  return text.append(this, pos, end).toString().trim()
}
