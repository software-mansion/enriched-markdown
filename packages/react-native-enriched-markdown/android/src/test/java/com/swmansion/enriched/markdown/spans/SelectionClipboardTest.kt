package com.swmansion.enriched.markdown.spans

import android.graphics.Color
import com.facebook.react.bridge.JavaOnlyArray
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.renderer.BlockStyle
import com.swmansion.enriched.markdown.renderer.SpanStyleCache
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class SelectionClipboardTest {
  private val context = RuntimeEnvironment.getApplication()
  private val block = BlockStyle(fontSize = 16f, fontFamily = "", fontWeight = "normal", color = Color.BLACK)

  @Test
  fun copiedLinkTextRetainsApplicationIdentityInPartialSelections() {
    val text = android.text.SpannableString("before Context after")
    text.setSpan(LinkSpan("ref:one", null, null, styleCache(), block, context), 7, 14, android.text.Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val config =
      com.swmansion.enriched.markdown.utils.text.view
        .SelectionClipboardConfig(mapOf("ref:one" to "[Context](ref:one)"))
    assertEquals(
      "before [Context](ref:one) after",
      com.swmansion.enriched.markdown.utils.text.view
        .canonicalClipboardText(text, config),
    )
    assertEquals(
      "[Context](ref:one)",
      com.swmansion.enriched.markdown.utils.text.view
        .canonicalClipboardText(text.subSequence(9, 12) as android.text.Spanned, config),
    )
    assertEquals(
      null,
      com.swmansion.enriched.markdown.utils.text.view
        .canonicalClipboardText(text.subSequence(0, 6) as android.text.Spanned, config),
    )
  }

  @Test
  fun clipboardMetadataKeepsHtmlContentAndEscapesAttributes() {
    val config =
      com.swmansion.enriched.markdown.utils.text.view.SelectionClipboardConfig(
        htmlAttributes =
          mapOf(
            "data-context" to "a\"&<",
            "bad name" to "ignored",
          ),
      )
    assertEquals(
      "<div data-context=\"a&quot;&amp;&lt;\"><b>Context</b></div>",
      com.swmansion.enriched.markdown.utils.text.view
        .clipboardHtml("<b>Context</b>", config),
    )
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
