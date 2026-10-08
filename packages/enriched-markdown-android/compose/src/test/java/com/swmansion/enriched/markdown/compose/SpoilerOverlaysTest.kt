package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import org.junit.Assert.assertEquals
import org.junit.Test

class SpoilerOverlaysTest {
  @Test
  fun aSolidOverlayTakesItsCornerRadiusAsDp() {
    assertEquals(SpoilerOverlay.Solid(cornerRadius = 6f), SpoilerOverlay.Solid(cornerRadius = 6.dp))
  }

  @Test
  fun aSolidOverlayWithoutArgumentsStillUsesItsDefault() {
    assertEquals(SpoilerOverlay.Solid(cornerRadius = 4f), SpoilerOverlay.Solid())
  }
}
