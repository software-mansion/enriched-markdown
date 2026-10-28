package com.swmansion.enriched.markdown

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CodeBlockWrapStateTest {
  @Test
  fun keepsStateWhileTheDocumentGrows() {
    assertTrue(keepsCodeBlockWrapState("a\nb", "a\nb\nc"))
    // The unfinished last line may be rewritten.
    assertTrue(keepsCodeBlockWrapState("a\n<b", "a\n<br>\nc"))
    // A single-line document has no stable prefix yet.
    assertTrue(keepsCodeBlockWrapState("abc", "xyz"))
  }

  @Test
  fun resetsWhenAnEarlierLineChanges() {
    assertFalse(keepsCodeBlockWrapState("a\nb\nc", "x\nb\nc"))
    assertFalse(keepsCodeBlockWrapState("a\nb\nc", "a\nx\nc"))
    // Shorter than the stable prefix.
    assertFalse(keepsCodeBlockWrapState("a\nb\nc", "a\n"))
  }

  @Test
  fun cursorCountsInVisitOrder() {
    val cursor = CodeBlockWrapCursor(setOf(1, 3))
    assertEquals(listOf(false, true, false, true, false), List(5) { cursor.nextIsWrapped() })
  }
}
