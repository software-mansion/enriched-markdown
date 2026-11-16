package com.swmansion.enriched.markdown.styles

import android.graphics.Color
import com.facebook.react.bridge.JavaOnlyMap
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class AdmonitionTitleStyleTest {
  private fun quote(vararg titles: Pair<String, String>) =
    styleConfig(
      blockquote =
        mapOf(
          "admonitions" to
            JavaOnlyMap().apply {
              for ((type, title) in titles) {
                putMap(type, JavaOnlyMap.of("color", Color.BLUE, "backgroundColor", Color.TRANSPARENT, "title", title))
              }
            },
        ),
    ).blockquoteStyle

  @Test
  fun `reads each type's title`() {
    val admonitions = quote("note" to "Notatka", "tip" to "").admonitions

    assertEquals("Notatka", admonitions.getValue("note").title)
    assertEquals("", admonitions.getValue("tip").title)
  }

  @Test
  fun `a title change alone changes the style, so the view re-renders`() {
    assertEquals(quote("note" to "Note"), quote("note" to "Note"))
    assertNotEquals(quote("note" to "Note"), quote("note" to "Notiz"))
  }
}
