package com.swmansion.enriched.markdown

import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.WRITING_DIRECTION_WORD_MAJORITY
import com.swmansion.enriched.markdown.utils.text.withoutDirectionControls
import com.swmansion.enriched.markdown.utils.text.wordMajorityAST
import com.swmansion.enriched.markdown.utils.text.wordMajorityDirection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class WordMajorityTest {
  @Test
  fun mostWordsDecideAndTiesGoToTheFirstWord() {
    assertEquals("rtl", wordMajorityDirection("StrictMode: يعيد العرض مرتين"))
    assertEquals("rtl", wordMajorityDirection("Device hub: מאפשר לנהל מכשירים מכל מקום."))
    assertEquals("ltr", wordMajorityDirection("The translation is \"שלום עולם\"."))
    assertEquals("ltr", wordMajorityDirection("Hello مرحبا"))
    assertEquals("rtl", wordMajorityDirection("مرحبا Hello"))
    assertEquals(null, wordMajorityDirection("123 456."))
  }

  @Test
  fun englishLedArabicParagraphRendersRtlWithIsolatedCode() {
    val style = MarkdownRenderTestSupport.styleConfig()
    val code = MarkdownASTNode(NodeType.Code, children = listOf(text("fetch()")))
    val ast =
      MarkdownASTNode(
        NodeType.Document,
        children = listOf(paragraph(text("React: يستدعي الدالة "), code, text(" مرتين"))),
      )

    val rendered =
      MarkdownRenderTestSupport.render(
        style,
        *wordMajorityAST(ast, style, WRITING_DIRECTION_WORD_MAJORITY).children.toTypedArray(),
      )
    val plain = MarkdownRenderTestSupport.render(style, *ast.children.toTypedArray()).toString()

    assertEquals('\u200F', rendered.first())
    assertEquals(true, rendered.contains("\u2066fetch()\u2069"))
    // Copy drops only the marks the renderer inserted.
    assertEquals(plain, withoutDirectionControls(rendered).toString())
  }

  @Test
  fun otherModesLeaveTheTreeAlone() {
    val style = MarkdownRenderTestSupport.styleConfig()
    val ast = MarkdownASTNode(NodeType.Document, children = listOf(paragraph(text("مرحبا"))))
    assertSame(ast, wordMajorityAST(ast, style, "first-strong"))
  }
}
