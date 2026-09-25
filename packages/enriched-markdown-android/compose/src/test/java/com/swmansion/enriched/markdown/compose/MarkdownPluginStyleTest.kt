package com.swmansion.enriched.markdown.compose

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.compose.style.StyleResolveContext
import com.swmansion.enriched.markdown.compose.test.ComposeStyleTestSupport
import com.swmansion.enriched.markdown.compose.test.FakePluginStyle
import com.swmansion.enriched.markdown.compose.test.FakePluginStyleKey
import com.swmansion.enriched.markdown.compose.test.OtherFakePluginStyleKey
import com.swmansion.enriched.markdown.compose.test.fakePlugin
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class MarkdownPluginStyleTest {
  @get:Rule
  val composeRule = createComposeRule()

  private val density = ComposeStyleTestSupport.testDensity

  private fun resolveContext(): StyleResolveContext {
    var resolveContext: StyleResolveContext? = null
    composeRule.setContent {
      resolveContext = ComposeStyleTestSupport.rememberResolveContext()
    }
    composeRule.waitForIdle()
    return requireNotNull(resolveContext)
  }

  private fun resolveFakePlugin(style: MarkdownStyle): FakePluginStyle? = style.resolve(resolveContext())[FakePluginStyleKey]

  @Test
  fun resolvesPluginPatchIntoExtensions() {
    val style = markdownStyle { fakePlugin { fontSize = 20.sp } }

    val resolved = requireNotNull(resolveFakePlugin(style))

    assertEquals(with(density) { 20.sp.toPx() }, resolved.fontSize, 0.01f)
  }

  @Test
  fun keysNoLayerTouchesStayAbsent() {
    val style = markdownStyle { fakePlugin { fontSize = 20.sp } }

    assertNull(style.resolve(resolveContext())[OtherFakePluginStyleKey])
  }

  @Test
  fun usesPluginDefaultWhenNoEarlierLayerSetTheKey() {
    val style = markdownStyle { fakePlugin { fontSize = 20.sp } }

    val resolved = requireNotNull(resolveFakePlugin(style))

    assertEquals(0xFF445566.toInt(), resolved.color)
    assertEquals(with(density) { FakePluginStyle.DEFAULT_PADDING.toPx() }, resolved.padding, 0.01f)
  }

  @Test
  fun repeatedBlocksMergeInsteadOfReplacing() {
    val style =
      markdownStyle {
        fakePlugin { fontSize = 20.sp }
        fakePlugin { color = Color(0xFF112233) }
      }

    val resolved = requireNotNull(resolveFakePlugin(style))

    assertEquals(with(density) { 20.sp.toPx() }, resolved.fontSize, 0.01f)
    assertEquals(0xFF112233.toInt(), resolved.color)
  }

  @Test
  fun copyLayersOverEarlierPluginPatch() {
    val base =
      markdownStyle {
        fakePlugin {
          fontSize = 20.sp
          padding = 12.dp
        }
      }

    val resolved = requireNotNull(resolveFakePlugin(base.merge { fakePlugin { padding = 2.dp } }))

    assertEquals(with(density) { 20.sp.toPx() }, resolved.fontSize, 0.01f)
    assertEquals(with(density) { 2.dp.toPx() }, resolved.padding, 0.01f)
  }

  @Test
  fun aLayerTouchingOnePluginKeepsAnotherPluginsValue() {
    val style =
      markdownStyle {
        fakePlugin(OtherFakePluginStyleKey) { fontSize = 30.sp }
      }.merge {
        fakePlugin { fontSize = 20.sp }
      }

    val resolved = style.resolve(resolveContext())

    assertEquals(with(density) { 20.sp.toPx() }, requireNotNull(resolved[FakePluginStyleKey]).fontSize, 0.01f)
    assertEquals(with(density) { 30.sp.toPx() }, requireNotNull(resolved[OtherFakePluginStyleKey]).fontSize, 0.01f)
  }

  /** A style rebuilt on every composition must stay `equals`, or Compose recomposes forever. */
  @Test
  fun identicallyBuiltStylesWithPluginPatchesAreEqual() {
    fun build() =
      markdownStyle {
        paragraph { color = Color(0xFF112233) }
        fakePlugin {
          fontSize = 20.sp
          color = Color(0xFF445566)
        }
      }

    assertEquals(build(), build())
    assertEquals(build().hashCode(), build().hashCode())
  }

  @Test
  fun stylesWithDifferentPluginPatchesAreNotEqual() {
    val first = markdownStyle { fakePlugin { fontSize = 20.sp } }
    val second = markdownStyle { fakePlugin { fontSize = 21.sp } }

    assertNotEquals(first, second)
  }
}
