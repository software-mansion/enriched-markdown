package com.swmansion.enriched.markdown.spans

import android.graphics.Color
import android.graphics.Typeface
import android.text.TextPaint
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class RecognizedLinkFontTest {
  private val context = RuntimeEnvironment.getApplication()
  private val block = BlockStyle(fontSize = 16f, fontFamily = "", fontWeight = "normal", color = Color.BLACK)

  @Test
  fun recognizedTextUsesVariantFontAndUnmatchedLinksUseBaseFont() {
    val style = styleCache()
    val matched = TextPaint()
    LinkSpan("ref:one", null, null, style, block, context, recognizedLink = true).updateDrawState(matched)
    assertEquals(Typeface.create("monospace", Typeface.NORMAL), matched.typeface)
    assertEquals(block.fontSize, matched.textSize, 0f)

    val unmatched = TextPaint()
    LinkSpan("https://example.com", null, null, style, block, context).updateDrawState(unmatched)
    assertEquals(Typeface.create("serif", Typeface.NORMAL), unmatched.typeface)
  }

  @Test
  fun recognizedCodeRetainsCodeFontAndSizeWithMatchingVariant() {
    val originalFont = Typeface.create("sans-serif", Typeface.BOLD)
    val paint =
      TextPaint().apply {
        typeface = originalFont
        textSize = 23f
      }
    LinkSpan("ref:one", null, null, styleCache(), block, context, preserveCodeFont = true, recognizedLink = true)
      .updateDrawState(paint)
    assertSame(originalFont, paint.typeface)
    assertEquals(23f, paint.textSize, 0f)
    assertEquals(Color.BLUE, paint.color)
  }

  private fun styleCache(): SpanStyleCache {
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(context)

    fun element() =
      JavaOnlyMap.of(
        "fontFamily",
        "",
        "fontWeight",
        "normal",
        "fontSize",
        16.0,
        "lineHeight",
        0.0,
        "marginTop",
        0.0,
        "marginBottom",
        0.0,
        "color",
        Color.BLACK,
        "backgroundColor",
        Color.TRANSPARENT,
        "borderColor",
        Color.TRANSPARENT,
        "underline",
        false,
        "fontScale",
        0.8,
        "baselineOffsetScale",
        0.5,
      )

    val style = JavaOnlyMap()
    listOf("paragraph", "strong", "em", "strikethrough", "code", "superscript", "subscript", "highlight")
      .forEach { style.putMap(it, element()) }
    style.putMap("link", element().apply { putString("fontFamily", "serif") })
    style.putArray(
      "linkVariants",
      JavaOnlyArray.of(
        element().apply {
          putString("pattern", "^ref:")
          putString("fontFamily", "monospace")
          putInt("color", Color.BLUE)
        },
      ),
    )
    style.putMap(
      "spoiler",
      element().apply {
        putMap("particles", JavaOnlyMap.of("density", 0.5, "speed", 1.0))
        putMap("solid", JavaOnlyMap.of("borderRadius", 0.0))
      },
    )
    style.putMap(
      "taskList",
      JavaOnlyMap.of(
        "checkedColor",
        Color.BLACK,
        "borderColor",
        Color.BLACK,
        "checkmarkColor",
        Color.BLACK,
        "checkedTextColor",
        Color.BLACK,
        "checkboxSize",
        16.0,
        "checkboxBorderRadius",
        0.0,
        "checkedStrikethrough",
        false,
      ),
    )
    return SpanStyleCache(StyleConfig(style, context, false, 0f))
  }
}
