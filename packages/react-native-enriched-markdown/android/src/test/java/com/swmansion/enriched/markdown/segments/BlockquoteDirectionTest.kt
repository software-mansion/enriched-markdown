package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import kotlin.math.ceil

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class BlockquoteDirectionTest {
  private val context = RuntimeEnvironment.getApplication()
  private val style by lazy { styleConfig() }
  private val barInset by lazy {
    val quote = style.blockquoteStyle
    ceil(quote.borderWidth + quote.gapWidth + quote.padding).toInt()
  }

  private fun quote(vararg children: MarkdownASTNode) = MarkdownASTNode(MarkdownASTNode.NodeType.Blockquote, children = children.toList())

  private fun codeBlock(code: String) = MarkdownASTNode(MarkdownASTNode.NodeType.CodeBlock, children = listOf(text(code)))

  private fun admonition(vararg children: MarkdownASTNode) =
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
        MarkdownASTNode(
          MarkdownASTNode.NodeType.Admonition,
          attributes = mapOf("admonitionType" to "tip"),
          children = children.toList(),
        ),
      )
    }

  @Test
  fun `the body's first strong character puts the bar on its side`() {
    assertEquals(barInset, admonition(paragraph(text("A tip"))).paddingLeft)
    assertEquals(barInset, admonition(paragraph(text("نصيحة تساعدك"))).paddingRight)
    assertEquals("digits have no direction", barInset, admonition(paragraph(text("2024")), paragraph(text("نصيحة"))).paddingRight)
  }

  @Test
  fun `a nested quote takes the side of the quote around it, as on web`() {
    val outer = admonition(paragraph(text("نصيحة")), quote(paragraph(text("English"))))
    val nested = (0 until outer.childCount).map(outer::getChildAt).filterIsInstance<BlockquoteContainerView>().single()

    assertEquals(barInset, outer.paddingRight)
    assertEquals(barInset, nested.paddingRight)
  }

  @Test
  fun `nested quotes count and code blocks do not, as on web`() {
    assertEquals(barInset, admonition(quote(paragraph(text("نصيحة")))).paddingRight)
    assertEquals(barInset, admonition(codeBlock("npm i"), paragraph(text("نصيحة"))).paddingRight)
  }
}
