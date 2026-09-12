package com.swmansion.enriched.markdown.compose.style

import android.graphics.Typeface
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.text.font.FontFamily
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.utils.text.TypefaceUtils
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class FontFamilyResolverTest {
  @get:Rule
  val composeRule = createComposeRule()

  @Test
  fun mapsSystemMonospaceToKey() {
    var resolveContext: StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val key = FontFamilyResolver.resolve(FontFamily.Monospace, requireNotNull(resolveContext))
    assertEquals("monospace", key)
  }

  @Test
  fun registeredComposeFontIsLoadable() {
    var resolveContext: StyleResolveContext? = null

    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()

    val typeface = Typeface.DEFAULT_BOLD
    val key = ComposeFontRegistry.register(typeface)

    assertNotNull(key)
    val loaded = TypefaceUtils.loadFontFamily(ComposeStyleTestSupport.context, key)
    assertSame(typeface, loaded)
  }

  @Test
  fun deduplicatesRegisteredComposeFonts() {
    val typeface = Typeface.DEFAULT_BOLD

    val firstKey = ComposeFontRegistry.register(typeface)
    val secondKey = ComposeFontRegistry.register(typeface)

    assertEquals(firstKey, secondKey)
  }
}
