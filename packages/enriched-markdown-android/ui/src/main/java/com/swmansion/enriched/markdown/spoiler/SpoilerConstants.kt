package com.swmansion.enriched.markdown.spoiler

internal const val REVEAL_DURATION_MS = 450L

/** Opacity of the overlay at [progress] through a reveal; the text fades in by the complement. */
internal fun overlayAlphaAt(progress: Float): Float = (1f - progress) * (1f - progress)
