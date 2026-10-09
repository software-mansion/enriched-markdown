package com.swmansion.enriched.markdown.plugin

/**
 * Marks a plugin's character style whose foreground color an enclosing list item keeps.
 *
 * A list item's span is set after its children and repaints every color it does not preserve, so
 * a color a plugin set inside it, e.g. a syntax token's, would come out in the list's color. The
 * list item moves spans carrying this marker after its own, so their color applies last.
 */
@InternalPluginApi
interface PreservedColorSpan
