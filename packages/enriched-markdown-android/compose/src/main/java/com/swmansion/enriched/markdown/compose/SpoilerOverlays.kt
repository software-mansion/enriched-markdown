package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.unit.Dp
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay

/**
 * [SpoilerOverlay.Solid] with its corner radius as a [Dp], for Compose code:
 * `SpoilerOverlay.Solid(cornerRadius = 6.dp)`.
 */
operator fun SpoilerOverlay.Solid.Companion.invoke(cornerRadius: Dp): SpoilerOverlay.Solid = SpoilerOverlay.Solid(cornerRadius.value)
