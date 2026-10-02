package com.swmansion.enriched.markdown.spoiler

import com.swmansion.enriched.markdown.styles.SpoilerStyle

/**
 * How unrevealed `||spoiler||` text is concealed: one of the built-ins, or a [CustomSpoilerOverlay].
 * Colors come from the theme's [SpoilerStyle].
 */
sealed interface SpoilerOverlay {
  /**
   * A field of drifting particles, the default.
   *
   * @property density how thickly the field is populated; the particle count scales linearly.
   * @property speed how fast the particles drift; their velocity scales linearly.
   */
  data class Particles(
    val density: Float = DEFAULT_DENSITY,
    val speed: Float = DEFAULT_SPEED,
  ) : SpoilerOverlay {
    internal companion object {
      const val DEFAULT_DENSITY = 8f
      const val DEFAULT_SPEED = 20f
    }
  }

  /**
   * A solid rounded box in the style's color.
   *
   * @property cornerRadius in dp.
   */
  data class Solid(
    val cornerRadius: Float = DEFAULT_CORNER_RADIUS,
  ) : SpoilerOverlay {
    internal companion object {
      const val DEFAULT_CORNER_RADIUS = 4f
    }
  }
}

/**
 * An overlay of the app's own: builds one [SpoilerSegmentOverlay] for each line segment of every
 * concealed spoiler, which draws the effect on the text view's canvas.
 *
 * A view rebuilds its overlays only when the new value is not `==` to the previous one, so make
 * implementations data classes or objects and keep their parameters in properties. A plain class
 * created anew on each call (such as in every recomposition) restarts every overlay each time.
 */
interface CustomSpoilerOverlay : SpoilerOverlay {
  /**
   * Called on the main thread whenever a segment comes into view: on the first draw, and again
   * after the text reflows or the overlay or style changes. Keep it cheap.
   */
  fun createSegment(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSegmentOverlay

  /**
   * How long a reveal takes, in milliseconds: [SpoilerSegmentOverlay.drawReveal]'s progress and
   * the text fading in underneath both run over it. Zero or less reveals at once, without calling
   * `drawReveal`.
   */
  val revealDurationMillis: Long get() = REVEAL_DURATION_MS
}

/** The text view a [SpoilerSegmentOverlay] draws into. */
interface SpoilerOverlayHost {
  /** Pixels per dp on the view's display. */
  val density: Float

  /** The user's font scale: pixels per sp are [density] times this. */
  val fontScale: Float

  /**
   * Asks for one more draw, for example after an asset the overlay needs has loaded. Safe to call
   * from any thread. An overlay that animates sets [SpoilerSegmentOverlay.isAnimated] instead.
   */
  fun invalidate()
}

internal val SpoilerOverlay.revealDurationMillis: Long
  get() = if (this is CustomSpoilerOverlay) revealDurationMillis else REVEAL_DURATION_MS

internal fun SpoilerOverlay.createSegmentOverlay(
  host: SpoilerOverlayHost,
  style: SpoilerStyle,
): SpoilerSegmentOverlay =
  when (this) {
    is SpoilerOverlay.Particles -> ParticleSegmentOverlay(style.color, density, speed)
    is SpoilerOverlay.Solid -> SolidSegmentOverlay(style.color, cornerRadius * host.density)
    is CustomSpoilerOverlay -> createSegment(host, style)
  }
