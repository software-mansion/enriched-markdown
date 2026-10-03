package com.swmansion.enriched.markdown.compose.patches

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import com.swmansion.enriched.markdown.compose.MarkdownStyleDsl
import com.swmansion.enriched.markdown.compose.style.StyleUnits
import com.swmansion.enriched.markdown.styles.SpoilerStyle

@Immutable
internal data class SpoilerStylePatch(
  val color: Color? = null,
  val particleDensity: Float? = null,
  val particleSpeed: Float? = null,
  val solidCornerRadius: Dp? = null,
) {
  fun apply(
    base: SpoilerStyle,
    units: StyleUnits,
  ): SpoilerStyle =
    base.copy(
      color = color?.let(units::color) ?: base.color,
      particleDensity = particleDensity ?: base.particleDensity,
      particleSpeed = particleSpeed ?: base.particleSpeed,
      solidCornerRadius = solidCornerRadius?.let(units::dp) ?: base.solidCornerRadius,
    )
}

/** Tuning for the drifting-particle overlay (`spoilerOverlay = SpoilerOverlay.Particles`). */
@MarkdownStyleDsl
class SpoilerParticlesStyleScope internal constructor() {
  /** Particles per 100x100 area. Higher values conceal more densely. */
  var density: Float? = null

  /** Base drift speed of the particles. */
  var speed: Float? = null
}

/** Tuning for the solid overlay (`spoilerOverlay = SpoilerOverlay.Solid`). */
@MarkdownStyleDsl
class SpoilerSolidStyleScope internal constructor() {
  /** Corner radius of the rectangles the solid overlay draws. */
  var cornerRadius: Dp? = null
}

@MarkdownStyleDsl
class SpoilerStyleScope internal constructor() {
  /** Color of the particles, and the fill of the solid overlay. */
  var color: Color? = null

  private var particleDensity: Float? = null
  private var particleSpeed: Float? = null
  private var solidCornerRadius: Dp? = null

  fun particles(block: SpoilerParticlesStyleScope.() -> Unit) {
    val scope = SpoilerParticlesStyleScope()
    scope.density = particleDensity
    scope.speed = particleSpeed
    scope.block()
    particleDensity = scope.density
    particleSpeed = scope.speed
  }

  fun solid(block: SpoilerSolidStyleScope.() -> Unit) {
    val scope = SpoilerSolidStyleScope()
    scope.cornerRadius = solidCornerRadius
    scope.block()
    solidCornerRadius = scope.cornerRadius
  }

  internal fun toPatch(): SpoilerStylePatch =
    SpoilerStylePatch(
      color = color,
      particleDensity = particleDensity,
      particleSpeed = particleSpeed,
      solidCornerRadius = solidCornerRadius,
    )

  internal companion object {
    fun merge(
      existing: SpoilerStylePatch?,
      block: SpoilerStyleScope.() -> Unit,
    ): SpoilerStylePatch {
      val scope =
        SpoilerStyleScope().apply {
          if (existing != null) {
            color = existing.color
            particles {
              density = existing.particleDensity
              speed = existing.particleSpeed
            }
            solid { cornerRadius = existing.solidCornerRadius }
          }
        }
      scope.apply(block)
      return scope.toPatch()
    }
  }
}
