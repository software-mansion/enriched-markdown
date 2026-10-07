@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.syntaxhighlighting

import android.text.Spanned
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.syntaxhighlighting.test.FakeTokenSource
import com.swmansion.enriched.markdown.syntaxhighlighting.test.FakeTokenSource.Companion.CODE
import com.swmansion.enriched.markdown.syntaxhighlighting.test.FakeTokenSource.Companion.LANGUAGE
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.codeBlock
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.defaultStyle
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.document
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.drawColorAt
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.listItem
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.paragraph
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.pluginWith
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.render
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.text
import com.swmansion.enriched.markdown.syntaxhighlighting.test.SyntaxHighlightingTestSupport.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class SyntaxHighlightDecoratorTest {
  /** Core's default code block is dark, so the dark palette applies. */
  @Test
  fun eachColoredTokenGetsOneSpanInThePalettesColor() {
    val rendered = render(document(paragraph(text("before")), codeBlock(CODE, LANGUAGE)), plugins = pluginWith(FakeTokenSource()))

    val dark = SyntaxHighlightStyle.githubDark()
    assertEquals(
      listOf(
        Token("def", SyntaxTokenType.KEYWORD, dark[SyntaxTokenType.KEYWORD]),
        Token("greet", SyntaxTokenType.FUNCTION, dark[SyntaxTokenType.FUNCTION]),
        Token("return", SyntaxTokenType.KEYWORD, dark[SyntaxTokenType.KEYWORD]),
        Token("\"hi \"", SyntaxTokenType.STRING, dark[SyntaxTokenType.STRING]),
        // `+` is an operator, which the palette leaves uncolored, so it gets no span at all.
        Token("# say hi", SyntaxTokenType.COMMENT, dark[SyntaxTokenType.COMMENT]),
      ),
      rendered.tokens(),
    )
    for (span in rendered.getSpans(0, rendered.length, SyntaxTokenSpan::class.java)) {
      assertEquals(Spanned.SPAN_EXCLUSIVE_EXCLUSIVE, rendered.getSpanFlags(span))
    }
  }

  @Test
  fun tokenColorsDrawOverTheBlocksTextColor() {
    val rendered = render(document(codeBlock(CODE, LANGUAGE)), plugins = pluginWith(FakeTokenSource()))

    assertEquals(SyntaxHighlightStyle.githubDark()[SyntaxTokenType.KEYWORD], drawColorAt(rendered, rendered.indexOf("def")))
    assertEquals(defaultStyle.codeBlockStyle.color, drawColorAt(rendered, rendered.indexOf("name")))
  }

  /** A list item's span is set after the block's tokens; the token span opts out of its repaint. */
  @Test
  fun tokenColorsSurviveInAListItem() {
    val rendered = render(document(unorderedList(listItem(codeBlock(CODE, LANGUAGE)))), plugins = pluginWith(FakeTokenSource()))

    assertEquals(SyntaxHighlightStyle.githubDark()[SyntaxTokenType.KEYWORD], drawColorAt(rendered, rendered.indexOf("def")))
  }

  @Test
  fun anUnknownLanguageGetsNoSpans() {
    val rendered = render(document(codeBlock(CODE, "cobol")), plugins = pluginWith(FakeTokenSource()))

    assertTrue(rendered.tokens().isEmpty())
  }

  @Test
  fun aFenceWithoutALanguageIsNotTokenized() {
    val source = FakeTokenSource()

    val rendered = render(document(codeBlock(CODE)), plugins = pluginWith(source))

    assertTrue(rendered.tokens().isEmpty())
    assertEquals(0, source.calls)
  }

  @Test
  fun aSecondRenderOfTheSameCodeHitsTheCache() {
    val source = FakeTokenSource()
    val plugins = pluginWith(source)

    val first = render(document(codeBlock(CODE, LANGUAGE)), plugins = plugins)
    val second = render(document(paragraph(text("moved")), codeBlock(CODE, LANGUAGE)), plugins = plugins)

    assertEquals(1, source.calls)
    assertEquals(first.tokens(), second.tokens())

    // The language is part of the key: the same code under another fence is tokenized again.
    render(document(codeBlock(CODE, "cobol")), plugins = plugins)
    assertEquals(2, source.calls)
  }

  @Test
  fun malformedTokensAreSkipped() {
    val source =
      SyntaxTokenSource { code, _ ->
        listOf(
          intArrayOf(0, 3, SyntaxTokenType.KEYWORD.ordinal),
          intArrayOf(4, 9, 99), // no such token type
          intArrayOf(5, code.length + 10, SyntaxTokenType.STRING.ordinal), // past the code
          intArrayOf(8, 8, SyntaxTokenType.STRING.ordinal), // empty
          intArrayOf(10), // a trailing partial triplet
        ).reduce(IntArray::plus)
      }

    val rendered = render(document(codeBlock(CODE, LANGUAGE)), plugins = pluginWith(source))

    assertEquals(
      listOf(Token("def", SyntaxTokenType.KEYWORD, SyntaxHighlightStyle.githubDark()[SyntaxTokenType.KEYWORD])),
      rendered.tokens(),
    )
  }

  /** The host JVM cannot load the grammars, which is exactly the library-missing case on a device. */
  @Test
  fun theRealPluginRendersUnhighlightedWithoutItsNativeLibrary() {
    val doc = document(codeBlock(CODE, LANGUAGE))

    val rendered = render(doc, plugins = PluginSnapshot.of(SyntaxHighlightingPlugin))

    assertTrue(rendered.tokens().isEmpty())
    assertEquals(render(doc).toString(), rendered.toString())
  }

  @Test
  fun thePluginRegistersOneDecoratorUnderAStableId() {
    assertEquals("com.swmansion.enriched.markdown.syntaxhighlighting", SyntaxHighlightingPlugin.id)
    val decorator = PluginSnapshot.of(SyntaxHighlightingPlugin).codeBlockDecorators.single()
    assertTrue(decorator is SyntaxHighlightDecorator)
  }

  private data class Token(
    val text: String,
    val type: SyntaxTokenType,
    val color: Int?,
  )

  private fun Spanned.tokens(): List<Token> =
    getSpans(0, length, SyntaxTokenSpan::class.java)
      .sortedBy { getSpanStart(it) }
      .map { Token(subSequence(getSpanStart(it), getSpanEnd(it)).toString(), it.type, it.foregroundColor) }
}
