package com.swmansion.enriched.markdown.styles

/**
 * Styling of the overlay that conceals `||spoiler||` text until it is tapped.
 *
 * [particleDensity] and [particleSpeed] are unitless tuning knobs (they are divided by the base
 * values the particle field was authored against), matching the React Native package. Unlike that
 * package, [solidBorderRadius] is stored in **pixels** like every other length here, so the solid
 * overlay does not re-apply the display density when it paints.
 */
data class SpoilerStyle(
  /** Color of the particles, and the fill of the solid overlay. */
  val color: Int = DEFAULT_COLOR,
  /**
   * Color the particle overlay paints over the concealed text before fading it out.
   *
   * Left `null`, it is inferred from the first ancestor view that carries a solid background,
   * falling back to white. Set it explicitly whenever the background lives on a Compose
   * `Modifier` rather than on the view itself — that is the common case, and inference cannot
   * see it.
   */
  val backgroundColor: Int? = null,
  /** Particles per 100x100 area. Higher values conceal more densely. */
  val particleDensity: Float = DEFAULT_PARTICLE_DENSITY,
  /** Base drift speed of the particles. */
  val particleSpeed: Float = DEFAULT_PARTICLE_SPEED,
  /** Corner radius, in pixels, of the rectangles the solid overlay draws. */
  val solidBorderRadius: Float = 0f,
) {
  companion object {
    const val DEFAULT_PARTICLE_DENSITY = 8f
    const val DEFAULT_PARTICLE_SPEED = 20f
    internal const val DEFAULT_COLOR = 0xFF374151.toInt()
  }
}
