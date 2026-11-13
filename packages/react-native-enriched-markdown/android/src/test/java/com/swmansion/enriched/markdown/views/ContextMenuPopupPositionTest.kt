package com.swmansion.enriched.markdown.views

import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * Where the block context menu goes: centered above its block, kept inside
 * the screen's margins, and pinned to the left margin when it is wider than
 * the screen instead of throwing.
 */
class ContextMenuPopupPositionTest {
  private val screenW = 1080
  private val margin = 21

  private fun position(
    centerX: Int,
    topY: Int = 1000,
    popupWidth: Int,
    popupHeight: Int = 300,
  ) = ContextMenuPopup.popupPosition(centerX, topY, popupWidth, popupHeight, screenW, margin)

  @Test
  fun narrowPopupIsCenteredAboveTheBlock() {
    assertEquals(540 - 200 to 1000 - 300 - margin, position(centerX = 540, popupWidth = 400))
  }

  @Test
  fun popupNearAnEdgeStaysInsideTheMargins() {
    assertEquals(margin, position(centerX = 50, popupWidth = 400).first)
    assertEquals(screenW - 400 - margin, position(centerX = 1050, popupWidth = 400).first)
  }

  @Test
  fun popupWiderThanTheScreenIsPinnedToTheLeftMargin() {
    assertEquals(margin, position(centerX = 540, popupWidth = 1749).first)
  }

  @Test
  fun popupAboveTheScreenTopIsPushedDownToTheMargin() {
    assertEquals(margin, position(centerX = 540, topY = 100, popupWidth = 400).second)
  }
}
