package com.swmansion.enriched.markdown

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import com.facebook.react.bridge.JavaOnlyMap
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.segments.BlockquoteContainerView
import com.swmansion.enriched.markdown.segments.DynamicBlockProps
import com.swmansion.enriched.markdown.segments.SegmentViewConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleMap
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class AdmonitionTitlesTest {
  private val context = RuntimeEnvironment.getApplication()

  private class TextRecorder(
    bitmap: Bitmap,
  ) : Canvas(bitmap) {
    val texts = mutableListOf<String>()

    override fun drawText(
      text: CharSequence,
      start: Int,
      end: Int,
      x: Float,
      y: Float,
      paint: Paint,
    ) {
      texts += text.subSequence(start, end).toString()
    }
  }

  private fun drawnTexts(titles: Map<String, String>): List<String> {
    val style = styleConfig().apply { admonitionTitles = titles }
    val quote =
      BlockquoteContainerView(
        context,
        SegmentViewConfig(
          context = context,
          style = style,
          allowFontScaling = true,
          maxFontSizeMultiplier = 0f,
          accessibilityLabels = AccessibilityLabels(),
          selectionMenuConfig = SelectionMenuConfig(),
          textBreakStrategy = "highQuality",
          selectable = false,
          selectionColor = null,
          selectionHandleColor = null,
          contextMenuItemTexts = emptyList(),
          dynamicProps = DynamicBlockProps(),
          onLinkPress = null,
          onLinkLongPress = null,
          onTaskListItemPress = null,
          onContextMenuItemPress = null,
        ),
      ).apply {
        applyBlockquoteNode(
          MarkdownASTNode(MarkdownASTNode.NodeType.Admonition, attributes = mapOf("admonitionType" to "note")),
        )
        layout(0, 0, WIDTH, HEIGHT)
      }
    return TextRecorder(Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)).also { quote.draw(it) }.texts
  }

  @Test
  fun `draws the title it gets through admonitionTitles`() {
    assertEquals(listOf("Uwaga"), drawnTexts(mapOf("note" to "Uwaga")))
  }

  @Test
  fun `an empty or missing title leaves the icon alone`() {
    assertEquals(emptyList<String>(), drawnTexts(mapOf("note" to "")))
    assertEquals(emptyList<String>(), drawnTexts(emptyMap()))
  }

  @Test
  fun `titles from the manager reach a style set after them and survive a font scale change`() {
    val view = EnrichedMarkdown(context)
    EnrichedMarkdownManager().setAdmonitionTitles(
      view,
      JavaOnlyMap.of("note", "Uwaga", "tip", "", "important", "Ważne", "warning", "Ostrzeżenie", "caution", "Ostrożnie"),
    )
    view.setMarkdownStyle(styleMap())
    val expected =
      mapOf("note" to "Uwaga", "tip" to "", "important" to "Ważne", "warning" to "Ostrzeżenie", "caution" to "Ostrożnie")

    assertEquals(expected, view.markdownStyle!!.admonitionTitles)
    view.setAllowFontScaling(false)
    assertEquals(expected, view.markdownStyle!!.admonitionTitles)
  }

  private companion object {
    const val WIDTH = 1000
    const val HEIGHT = 200
  }
}
