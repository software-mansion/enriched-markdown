package com.swmansion.enriched.markdown.styles

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class StyleConfigExtensionTest {
  private val context: Context = ApplicationProvider.getApplicationContext()
  private val key = StyleExtensionKey<Marker>("test:marker")

  private data class Marker(
    val value: Int,
  )

  @Test
  fun withExtensionStoresTheValueUnderItsKeyOnly() {
    val base = StyleConfig.default(context)

    val extended = base.withExtension(key, Marker(1))

    assertEquals(Marker(1), extended[key])
    assertNull(base[key])
    assertNull(extended[StyleExtensionKey<Marker>("test:marker")])
    assertNotEquals(base, extended)
  }

  /** The copy is written out by hand, so a property it forgets silently resets to its default. */
  @Test
  fun withExtensionKeepsEveryOtherProperty() {
    val base = StyleConfig.default(context)
    val extended = base.withExtension(key, Marker(1))

    assertEquals(base.spoilerStyle, extended.spoilerStyle)

    val getters =
      StyleConfig::class.java.methods.filter { method ->
        method.parameterCount == 0 &&
          method.name.startsWith("get") &&
          method.name != "getExtensions" &&
          method.declaringClass == StyleConfig::class.java
      }
    assertTrue(getters.size > 10)
    for (getter in getters) {
      val expected = getter.invoke(base)
      val actual = getter.invoke(extended)
      assertTrue(
        "${getter.name} was not carried over",
        java.util.Objects.deepEquals(expected, actual),
      )
    }
  }

  /** Table cells render with this from the render thread, while other views read the same config. */
  @Test
  fun withParagraphStyleLeavesTheSharedConfigUntouched() {
    val base = StyleConfig.default(context)
    val cellStyle = base.tableCellParagraphStyle(isHeader = true)

    val cell = base.withParagraphStyle(cellStyle)

    assertEquals(cellStyle, cell.paragraphStyle)
    assertNotEquals(cellStyle, base.paragraphStyle)
    assertEquals(base.highlightStyle, cell.highlightStyle)
  }
}
