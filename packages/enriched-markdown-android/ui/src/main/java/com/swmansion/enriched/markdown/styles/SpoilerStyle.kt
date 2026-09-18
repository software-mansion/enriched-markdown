package com.swmansion.enriched.markdown.styles

data class SpoilerStyle(
  val color: Int = DEFAULT_COLOR,
  val backgroundColor: Int? = null,
  val particleDensity: Float = DEFAULT_PARTICLE_DENSITY,
  val particleSpeed: Float = DEFAULT_PARTICLE_SPEED,
  val solidBorderRadius: Float = 0f,
) {
  companion object {
    const val DEFAULT_PARTICLE_DENSITY = 8f
    const val DEFAULT_PARTICLE_SPEED = 20f
    internal const val DEFAULT_COLOR = 0xFF374151.toInt()
  }
}
