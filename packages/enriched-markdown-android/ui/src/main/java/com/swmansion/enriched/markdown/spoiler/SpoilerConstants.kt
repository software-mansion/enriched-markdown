package com.swmansion.enriched.markdown.spoiler

internal const val REVEAL_DURATION_MS = 450L

// Top level rather than in internal companions, which made a bare `SpoilerOverlay.Particles` fail
// as an inaccessible companion instead of pointing to the missing constructor call.
internal const val DEFAULT_PARTICLE_DENSITY = 8f
internal const val DEFAULT_PARTICLE_SPEED = 20f
internal const val DEFAULT_SOLID_CORNER_RADIUS = 4f

/** Opacity of the overlay at [progress] through a reveal; the text fades in by the complement. */
internal fun overlayAlphaAt(progress: Float): Float = (1f - progress) * (1f - progress)
