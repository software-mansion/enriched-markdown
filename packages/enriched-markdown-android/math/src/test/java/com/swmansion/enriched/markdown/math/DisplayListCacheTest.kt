package com.swmansion.enriched.markdown.math

import androidx.test.ext.junit.runners.AndroidJUnit4
import io.ratex.DisplayList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** The RaTeX engine cannot load under Robolectric, so the parse here is a stand-in that counts calls. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class DisplayListCacheTest {
  private val parsed = mutableListOf<String>()
  private val cache =
    DisplayListCache(maxSize = 2) { latex, displayMode, color ->
      parsed += "$latex:$displayMode:$color"
      DisplayList(width = 1.0, height = 1.0, depth = 0.0, items = emptyList())
    }

  @Test
  fun anEquationSeenBeforeIsNotParsedAgain() {
    val first = cache.get("x^2", displayMode = false, color = 0)
    val second = cache.get("x^2", displayMode = false, color = 0)

    assertSame(first, second)
    assertEquals(listOf("x^2:false:0"), parsed)
  }

  /** Mode and color change what the engine lays out, so each is a parse of its own. */
  @Test
  fun modeAndColorArePartOfTheKey() {
    cache.get("x^2", displayMode = false, color = 0)
    cache.get("x^2", displayMode = true, color = 0)
    cache.get("x^2", displayMode = false, color = 1)

    assertEquals(listOf("x^2:false:0", "x^2:true:0", "x^2:false:1"), parsed)
  }

  @Test
  fun theLeastRecentlyUsedEquationIsEvictedFirst() {
    cache.get("a", displayMode = false, color = 0)
    cache.get("b", displayMode = false, color = 0)
    cache.get("a", displayMode = false, color = 0)
    cache.get("c", displayMode = false, color = 0)
    parsed.clear()

    cache.get("a", displayMode = false, color = 0)
    cache.get("b", displayMode = false, color = 0)

    assertEquals(listOf("b:false:0"), parsed)
  }

  @Test
  fun aRejectedEquationIsParsedAgainNextTime() {
    var calls = 0
    val failing =
      DisplayListCache(maxSize = 2) { _, _, _ ->
        calls++
        throw IllegalArgumentException("bad")
      }

    repeat(2) { runCatching { failing.get("\\frac{", displayMode = false, color = 0) } }

    assertEquals(2, calls)
  }
}
