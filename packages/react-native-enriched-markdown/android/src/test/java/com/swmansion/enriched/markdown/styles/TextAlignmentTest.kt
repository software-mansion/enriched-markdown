package com.swmansion.enriched.markdown.styles

import android.text.Layout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TextAlignmentTest {
  @Test
  fun leftAndRightResolveAgainstTheParagraphDirection() {
    assertEquals(Layout.Alignment.ALIGN_NORMAL, TextAlignment.LEFT.layoutAlignment(isRtl = false))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, TextAlignment.LEFT.layoutAlignment(isRtl = true))
    assertEquals(Layout.Alignment.ALIGN_OPPOSITE, TextAlignment.RIGHT.layoutAlignment(isRtl = false))
    assertEquals(Layout.Alignment.ALIGN_NORMAL, TextAlignment.RIGHT.layoutAlignment(isRtl = true))
  }

  @Test
  fun centerAutoAndJustifyIgnoreTheDirection() {
    for (isRtl in listOf(false, true)) {
      assertEquals(Layout.Alignment.ALIGN_CENTER, TextAlignment.CENTER.layoutAlignment(isRtl))
      assertNull(TextAlignment.AUTO.layoutAlignment(isRtl))
      assertNull(TextAlignment.JUSTIFY.layoutAlignment(isRtl))
    }
  }

  @Test
  fun onlyLeftAndRightAreAbsolute() {
    assertTrue(TextAlignment.LEFT.isAbsolute)
    assertTrue(TextAlignment.RIGHT.isAbsolute)
    assertFalse(TextAlignment.CENTER.isAbsolute)
    assertFalse(TextAlignment.AUTO.isAbsolute)
    assertFalse(TextAlignment.JUSTIFY.isAbsolute)
  }

  @Test
  fun parsesTheJsValues() {
    assertEquals(TextAlignment.LEFT, TextAlignment.fromString("left"))
    assertEquals(TextAlignment.RIGHT, TextAlignment.fromString("right"))
    assertEquals(TextAlignment.CENTER, TextAlignment.fromString("center"))
    assertEquals(TextAlignment.JUSTIFY, TextAlignment.fromString("justify"))
    assertEquals(TextAlignment.AUTO, TextAlignment.fromString("auto"))
    assertTrue(TextAlignment.JUSTIFY.needsJustify)
    assertFalse(TextAlignment.LEFT.needsJustify)
  }
}
