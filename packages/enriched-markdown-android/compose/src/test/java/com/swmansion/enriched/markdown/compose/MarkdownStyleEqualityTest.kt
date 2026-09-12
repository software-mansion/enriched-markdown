package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

class MarkdownStyleEqualityTest {
  @Test
  fun equalStylesWithSameValuesAreEqual() {
    val first =
      markdownStyle {
        paragraph { color = Color(0xFF112233) }
        link { color = Color(0xFF445566) }
      }
    val second =
      markdownStyle {
        paragraph { color = Color(0xFF112233) }
        link { color = Color(0xFF445566) }
      }

    assertEquals(first, second)
    assertEquals(first.hashCode(), second.hashCode())
  }

  @Test
  fun stylesWithDifferentValuesAreNotEqual() {
    val first = markdownStyle { paragraph { color = Color(0xFF112233) } }
    val second = markdownStyle { paragraph { color = Color(0xFF445566) } }

    assertNotEquals(first, second)
  }
}
