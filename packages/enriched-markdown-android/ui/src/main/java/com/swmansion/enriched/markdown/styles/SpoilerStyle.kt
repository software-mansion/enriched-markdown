package com.swmansion.enriched.markdown.styles

/**
 * Style of the overlay that conceals `||spoiler||` text.
 *
 * The defaults here are placeholders for constructing a bare [StyleConfig]; the theme defaults
 * come from `DefaultStyles`, which sets a 4dp [solidCornerRadius].
 */
data class SpoilerStyle(
  val color: Int = DEFAULT_COLOR,
  val particleDensity: Float = DEFAULT_PARTICLE_DENSITY,
  val particleSpeed: Float = DEFAULT_PARTICLE_SPEED,
  val solidCornerRadius: Float = 0f,
) {
  companion object {
    const val DEFAULT_PARTICLE_DENSITY = 8f
    const val DEFAULT_PARTICLE_SPEED = 20f
    internal const val DEFAULT_COLOR = 0xFF374151.toInt()
  }
}
