package com.swmansion.enriched.markdown.accessibility

/** A replaced span TalkBack announces as its own element, labelled from the current [AccessibilityLabels]. */
interface SpokenSpan {
  fun accessibilityLabel(labels: AccessibilityLabels): String
}
