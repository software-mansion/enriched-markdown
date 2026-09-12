package com.swmansion.enriched.markdown

/**
 * Payload for a task-list checkbox tap: the item's 0-based index in document
 * order, its checked state *after* the toggle, and the first line of the item's
 * plain text.
 */
data class TaskListItemPressEvent(
  val index: Int,
  val checked: Boolean,
  val text: String,
)
