package com.swmansion.enriched.markdown.segments

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** A slot reads its kind from the core's attribute and takes the margins of the block it replaces. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class BlockSlotKindTest {
  private val style by lazy { styleConfig(codeBlock = mapOf("marginTop" to 12.0, "marginBottom" to 20.0)) }

  @Test
  fun everyCoreKindNameMapsToItsKind() {
    assertEquals(BlockSlotKind.IMAGE, BlockSlotKind.fromAttribute("image"))
    assertEquals(BlockSlotKind.VIDEO, BlockSlotKind.fromAttribute("video"))
    assertEquals(BlockSlotKind.LINK, BlockSlotKind.fromAttribute("link"))
    assertEquals(BlockSlotKind.CODE, BlockSlotKind.fromAttribute("code"))
  }

  @Test
  fun aCodeSlotTakesTheCodeBlockMargins() {
    assertTrue(style.codeBlockStyle.marginTop > style.paragraphStyle.marginTop)
    assertEquals(style.codeBlockStyle.marginTop.toInt(), BlockSlotKind.CODE.marginTop(style))
    assertEquals(style.codeBlockStyle.marginBottom.toInt(), BlockSlotKind.CODE.marginBottom(style))
  }

  @Test
  fun aStampedCodeBlockSplitsIntoACodeSlotAndAnUnstampedOneStaysNative() {
    val code = { attributes: Map<String, String> ->
      MarkdownASTNode(
        MarkdownASTNode.NodeType.CodeBlock,
        attributes = attributes + ("language" to "mermaid"),
        children = listOf(MarkdownASTNode(MarkdownASTNode.NodeType.Text, content = "graph TD\n")),
      )
    }
    val root =
      MarkdownASTNode(
        MarkdownASTNode.NodeType.Document,
        children =
          listOf(
            code(mapOf(BLOCK_SLOT_ID_ATTRIBUTE to "code:aaaa:0", BLOCK_SLOT_KIND_ATTRIBUTE to "code")),
            code(emptyMap()),
          ),
      )
    val segments = splitASTIntoSegments(root)

    assertEquals(MarkdownSegment.BlockSlot("code:aaaa:0", BlockSlotKind.CODE), segments[0])
    assertTrue(segments[1] is MarkdownSegment.CodeBlock)
  }
}
