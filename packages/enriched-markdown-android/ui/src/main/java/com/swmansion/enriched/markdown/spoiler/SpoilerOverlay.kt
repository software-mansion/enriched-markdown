package com.swmansion.enriched.markdown.spoiler

enum class SpoilerOverlay(
  internal val createStrategy: (SpoilerAnimator) -> SpoilerStrategy,
) {
  Particles({ animator -> ParticleStrategy(animator) }),
  Solid({ _ -> SolidStrategy() }),
}
