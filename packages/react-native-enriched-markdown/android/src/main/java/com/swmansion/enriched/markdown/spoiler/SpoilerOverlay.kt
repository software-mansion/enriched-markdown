package com.swmansion.enriched.markdown.spoiler

import com.swmansion.enriched.markdown.styles.SpoilerStyle

/**
 * The `spoilerOverlay` prop: which built-in overlay conceals unrevealed `||spoiler||` text. Its
 * tuning (particle density and speed, solid corner radius) comes from the `spoiler` markdown style.
 */
enum class SpoilerOverlayMode {
  PARTICLES,
  SOLID,
  ;

  /** The overlay this mode draws, tuned by [style]. */
  internal fun toOverlay(style: SpoilerStyle): SpoilerOverlay =
    when (this) {
      PARTICLES -> SpoilerOverlay.Particles(style.particleDensity, style.particleSpeed)
      SOLID -> SpoilerOverlay.Solid(style.solidBorderRadius)
    }

  companion object {
    fun fromString(value: String?): SpoilerOverlayMode =
      when (value) {
        "solid" -> SOLID
        else -> PARTICLES
      }
  }
}

/** How unrevealed `||spoiler||` text is concealed. Colors come from the theme's [SpoilerStyle]. */
internal sealed interface SpoilerOverlay {
  /**
   * A field of drifting particles, the default.
   *
   * @property density how thickly the field is populated; the particle count scales linearly.
   * @property speed how fast the particles drift; their velocity scales linearly.
   */
  data class Particles(
    val density: Float = DEFAULT_PARTICLE_DENSITY,
    val speed: Float = DEFAULT_PARTICLE_SPEED,
  ) : SpoilerOverlay

  /**
   * A solid rounded box in the style's color.
   *
   * @property cornerRadius in dp.
   */
  data class Solid(
    val cornerRadius: Float = DEFAULT_SOLID_CORNER_RADIUS,
  ) : SpoilerOverlay
}

/** The text view a [SpoilerSliceOverlay] draws into. */
internal interface SpoilerOverlayHost {
  /** Pixels per dp on the view's display. */
  val density: Float

  /** Asks for one more draw. Safe to call from any thread. */
  fun invalidate()
}

internal val SpoilerOverlay.revealDurationMillis: Long
  get() = REVEAL_DURATION_MS

internal fun SpoilerOverlay.createSliceOverlay(
  host: SpoilerOverlayHost,
  style: SpoilerStyle,
): SpoilerSliceOverlay =
  when (this) {
    is SpoilerOverlay.Particles -> ParticleSliceOverlay(style.color, density, speed)
    is SpoilerOverlay.Solid -> SolidSliceOverlay(style.color, cornerRadius * host.density)
  }
