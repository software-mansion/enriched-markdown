package com.swmansion.enriched.markdown.segments

import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TextRenderCacheTest {
  private val style = styleConfig()

  private fun heading(
    level: Int,
    content: String,
  ) = MarkdownASTNode(NodeType.Heading, attributes = mapOf("level" to level.toString()), children = listOf(text(content)))

  private fun strong(content: String) = MarkdownASTNode(NodeType.Strong, children = listOf(text(content)))

  private fun link(
    label: String,
    url: String,
  ) = MarkdownASTNode(NodeType.Link, attributes = mapOf("url" to url), children = listOf(text(label)))

  private fun blockquote(vararg children: MarkdownASTNode) = MarkdownASTNode(NodeType.Blockquote, children = children.toList())

  private fun codeBlock(code: String) = MarkdownASTNode(NodeType.CodeBlock, children = listOf(text(code)))

  // A block image: alone in its paragraph. The URL loads nothing, so it keeps its placeholder.
  private fun blockImage(name: String) = paragraph(MarkdownASTNode(NodeType.Image, attributes = mapOf("url" to "test://$name")))

  // Each block in the versions a stream shows while it arrives, the last one complete.
  private val blocks: List<List<MarkdownASTNode>> =
    listOf(
      listOf(heading(1, "Set"), heading(1, "Setting up")),
      listOf(
        paragraph(text("To get")),
        paragraph(text("To get started, install "), strong("the")),
        paragraph(text("To get started, install "), strong("the tools"), text(" and read the "), link("guide", "https://e.com")),
      ),
      listOf(
        unorderedList(listItem(paragraph(text("Clone")))),
        unorderedList(listItem(paragraph(text("Clone the repo"))), listItem(paragraph(text("Install")))),
      ),
      listOf(
        orderedList(listItem(paragraph(text("One"))), start = 3),
        orderedList(listItem(paragraph(text("One"))), listItem(paragraph(text("Two, with "), strong("bold"))), start = 3),
      ),
      listOf(
        unorderedList(taskListItem(false, paragraph(text("Done")))),
        unorderedList(taskListItem(true, paragraph(text("Done"))), taskListItem(false, paragraph(text("Next")))),
      ),
      listOf(heading(2, "Key"), heading(2, "Key steps")),
      listOf(blockImage("diagram")),
      listOf(
        blockquote(paragraph(text("Note"))),
        blockquote(paragraph(text("Note: keep the "), strong("key"))),
        blockquote(paragraph(text("Note: keep the "), strong("key")), paragraph(text("somewhere safe"))),
      ),
      listOf(codeBlock("npm"), codeBlock("npm install\n"), codeBlock("npm install\nnpm test\n")),
      listOf(MarkdownASTNode(NodeType.ThematicBreak)),
      listOf(blockImage("result")),
      listOf(paragraph(text("That's")), paragraph(text("That's it, you now have a "), strong("working setup"), text("."))),
    )

  // The states of the stream: every finished block, then a version of the next one.
  private val states: List<List<MarkdownASTNode>> =
    blocks.indices.flatMap { index ->
      blocks[index].map { version -> blocks.subList(0, index).map { it.last() } + version }
    }

  private fun render(
    nodes: List<MarkdownASTNode>,
    cache: TextRenderCache?,
  ): RenderedSegment.Text {
    cache?.begin(style)
    val rendered =
      MarkdownSegmentRenderer.render(
        listOf(MarkdownSegment.Text(nodes)),
        style,
        RuntimeEnvironment.getApplication(),
        onLinkPress = null,
        onLinkLongPress = null,
        cache = cache,
      )
    cache?.end()
    return rendered.single() as RenderedSegment.Text
  }

  private fun describe(text: Spanned): List<String> =
    listOf(text.toString()) +
      text
        .getSpans(0, text.length, Any::class.java)
        .map { "${it.javaClass.simpleName} ${text.getSpanStart(it)}..${text.getSpanEnd(it)} ${text.getSpanFlags(it)}" }
        .sorted()

  @Test
  fun everyStateRendersAsAFullRenderAndPatchesTheShownText() {
    val cache = TextRenderCache()
    var shown: SpannableStringBuilder? = null
    var shownRevision = 0L
    var patches = 0
    for (state in states) {
      val cached = render(state, cache)
      val full = render(state, null)
      val fullText = full.styledText!!
      cached.styledText?.let { assertEquals(describe(fullText), describe(it)) }
      assertEquals(full.signature, cached.signature)
      assertEquals(full.lastElementMarginBottom, cached.lastElementMarginBottom)

      val patch = cached.patch
      val view = shown
      if (patch != null && view != null && patch.baseRevision == shownRevision) {
        view.replaceTail(patch.start, patch.tail)
        patches++
      } else {
        shown = cached.styledText as SpannableStringBuilder
      }
      shownRevision = cached.revision
      val shownText = shown!!
      assertEquals(describe(fullText), describe(shownText))
      // A patch's image spans are the kept ones before it and the tail's.
      assertEquals(full.imageSpans.map { fullText.getSpanStart(it) }, cached.imageSpans.map { shownText.getSpanStart(it) })
    }
    assertTrue("patched $patches of ${states.size}", patches >= states.size - blocks.size)
  }

  @Test
  fun aLastNodeThatGoesAwayLeavesTheTextOfAFullRender() {
    // A link reference definition shows as text until its URL arrives, then renders nothing.
    val finished = blocks.map { it.last() }
    val cache = TextRenderCache()
    val shown = render(finished + paragraph(text("[api]:")), cache).styledText as SpannableStringBuilder
    val patch = render(finished, cache).patch!!
    shown.replaceTail(patch.start, patch.tail)
    assertEquals(describe(render(finished, null).styledText!!), describe(shown))
  }

  @Test
  fun anUnchangedSegmentIsHandedOverAsItWas() {
    val cache = TextRenderCache()
    val first = render(states.last(), cache)
    assertSame(first, render(states.last(), cache))
  }

  @Test
  fun aNewStyleRendersInFull() {
    val cache = TextRenderCache()
    render(states[3], cache)
    cache.begin(Any())
    cache.end()
    assertEquals(null, render(states[4], cache).patch)
  }
}
