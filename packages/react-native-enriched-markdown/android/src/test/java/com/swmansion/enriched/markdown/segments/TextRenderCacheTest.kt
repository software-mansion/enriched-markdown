package com.swmansion.enriched.markdown.segments

import android.text.SpannableStringBuilder
import android.text.Spanned
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.spans.OrderedListSpan
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
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
    renderStyle: com.swmansion.enriched.markdown.styles.StyleConfig = style,
  ): RenderedSegment.Text {
    cache?.begin(renderStyle)
    val rendered =
      MarkdownSegmentRenderer.render(
        listOf(MarkdownSegment.Text(nodes)),
        renderStyle,
        RuntimeEnvironment.getApplication(),
        onLinkPress = null,
        onLinkLongPress = null,
        cache = cache,
      )
    cache?.end()
    return rendered.single() as RenderedSegment.Text
  }

  // What a span draws besides its range: a list item's number, a task's index.
  private fun detail(span: Any): String =
    when (span) {
      is OrderedListSpan -> " #${span.itemNumber}"
      is TaskListSpan -> " task ${span.taskIndex}"
      else -> ""
    }

  private fun describe(text: Spanned): List<String> =
    listOf(text.toString()) +
      text
        .getSpans(0, text.length, Any::class.java)
        .map { "${it.javaClass.simpleName} ${text.getSpanStart(it)}..${text.getSpanEnd(it)} ${text.getSpanFlags(it)}${detail(it)}" }
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

  // Rendering resumes only after a node that ends in "\n": one that doesn't would join the next.
  @Test
  fun `resumes only where the text before ends in a newline`() {
    fun fakeRender(separator: String): (List<MarkdownASTNode>, Int) -> TextRenderResult =
      { nodes, taskIndex ->
        val text = SpannableStringBuilder()
        val starts = IntArray(nodes.size)
        nodes.forEachIndexed { i, node ->
          starts[i] = text.length
          text.append(node.children.first().content).append(separator)
        }
        TextRenderResult(text, emptyList(), false, 0f, taskIndex, starts, IntArray(nodes.size) { taskIndex })
      }
    val shown = listOf(paragraph(text("one")), paragraph(text("two")))
    val grown = shown + paragraph(text("three"))

    for ((separator, resumes) in listOf("\n" to true, " " to false)) {
      val cache = TextRenderCache()
      cache.begin(separator)
      cache.render(shown, 0, isLast = true, render = fakeRender(separator))
      cache.end()
      cache.begin(separator)
      val (segment, _) = cache.render(grown, 0, isLast = true, render = fakeRender(separator))
      cache.end()
      if (resumes) {
        assertNotNull(segment.patch)
      } else {
        assertNull(segment.patch)
        assertEquals("one two three ", segment.styledText.toString())
      }
    }
  }

  // Streams [states] through a cache, patching the text a view shows, and checks every state
  // against a full render. Returns how many states patched.
  private fun streamThroughCache(
    states: List<List<MarkdownASTNode>>,
    renderStyle: com.swmansion.enriched.markdown.styles.StyleConfig = style,
  ): Int {
    val cache = TextRenderCache()
    var shown: SpannableStringBuilder? = null
    var shownRevision = 0L
    var patches = 0
    for (state in states) {
      val cached = render(state, cache, renderStyle)
      val full = render(state, null, renderStyle)
      val fullText = full.styledText!!
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
      assertEquals(describe(fullText), describe(shown!!))
    }
    return patches
  }

  // A list a stream grows item by item, often a segment's only node: each update renders from
  // its first changed item, numbered on, and the view shows what a full render does.
  @Test
  fun aGrowingListRendersFromItsFirstChangedItem() {
    val items =
      listOf(
        listItem(paragraph(text("Alpha"))),
        listItem(paragraph(text("Beta, with "), strong("bold"))),
        listItem(paragraph(text("Gamma")), unorderedList(listItem(paragraph(text("nested one"))), listItem(paragraph(text("nested two"))))),
        listItem(paragraph(text("Delta and a "), link("link", "https://e.com"))),
        taskListItem(true, paragraph(text("Epsilon done"))),
        taskListItem(false, paragraph(text("Zeta next"))),
      )

    fun partial(item: MarkdownASTNode) = item.copy(children = listOf(paragraph(text("Wo"))))
    val versions = items.indices.flatMap { i -> listOf(items.subList(0, i) + partial(items[i]), items.subList(0, i + 1)) }
    val makers =
      listOf<(List<MarkdownASTNode>) -> List<MarkdownASTNode>>(
        { listOf(orderedList(*it.toTypedArray(), start = 3)) },
        { listOf(unorderedList(*it.toTypedArray())) },
        { listOf(heading(2, "Steps"), paragraph(text("Do these:")), orderedList(*it.toTypedArray())) },
      )
    for (make in makers) {
      val patches = streamThroughCache(versions.map(make))
      // Rendering resumes at the old render's last item at the latest, so only the states while
      // the list has a single item render it whole.
      assertTrue("patched $patches of ${versions.size}", patches >= versions.size - 3)
    }
  }

  // A change to the list itself, here its first number, renders every item again.
  @Test
  fun aChangedListRendersAllItsItemsAgain() {
    fun list(
      items: Int,
      start: Int,
    ) = orderedList(*(1..items).map { listItem(paragraph(text("Item $it"))) }.toTypedArray(), start = start)

    streamThroughCache(listOf(listOf(list(2, 1)), listOf(list(3, 1)), listOf(list(3, 7)), listOf(list(4, 7))))
  }

  // Numbers from 100 on widen every item's marker column, so such a list renders whole.
  @Test
  fun anOrderedListReachingANumberOf100RendersWhole() {
    fun list(items: Int) = orderedList(*(1..items).map { listItem(paragraph(text("Item $it"))) }.toTypedArray(), start = 97)

    val patches = streamThroughCache((2..5).map { listOf(list(it)) })
    // 97 and 98, then 97 to 99 patch; the lists reaching 100 and 101 render whole.
    assertEquals(1, patches)
  }

  // A list whose items have real spacing: the continuation skips the gap above the list, and the
  // spacing above its first item stays in the text before it.
  @Test
  fun aSpacedListRendersFromItsFirstChangedItemAsAFullRenderDoes() {
    val spaced = styleConfig(list = mapOf("marginTop" to 12.0, "marginBottom" to 16.0, "itemSpacing" to 8.0, "lineHeight" to 28.0))
    val items = (1..5).map { listItem(paragraph(text("Item $it with a few words"))) }
    val states = items.indices.map { listOf(orderedList(*items.subList(0, it + 1).toTypedArray(), start = 2)) }
    val patches = streamThroughCache(states, spaced)
    assertTrue("patched $patches of ${states.size}", patches >= states.size - 2)
  }

  // The patch starts at the first changed item, not at the list.
  @Test
  fun theListPatchStartsAtTheChangedItem() {
    val cache = TextRenderCache()
    val first = listItem(paragraph(text("First")))
    val second = listItem(paragraph(text("Second")))
    render(listOf(paragraph(text("Intro")), unorderedList(first, second)), cache)
    val grown = render(listOf(paragraph(text("Intro")), unorderedList(first, second, listItem(paragraph(text("Third"))))), cache)
    val full = render(listOf(paragraph(text("Intro")), unorderedList(first, second, listItem(paragraph(text("Third"))))), null)
    assertEquals(full.styledText.toString().indexOf("Second"), grown.patch!!.start)
  }

  // A chunk ending on an empty marker, and an item that turns blank (a link reference definition
  // completing): each state still shows what a full render does.
  @Test
  fun emptyAndBlankTrailingItemsShowAsAFullRender() {
    val a = listItem(paragraph(text("Alpha")))
    val b = listItem(paragraph(text("Beta")))
    streamThroughCache(
      listOf(
        listOf(unorderedList(a, b)),
        listOf(unorderedList(a, b, listItem())),
        listOf(unorderedList(a, b, listItem(paragraph(text("Gam"))))),
        listOf(unorderedList(a, b, listItem(paragraph(text("[ref]:"))))),
        listOf(unorderedList(a, b, listItem())),
        listOf(unorderedList(a, b, listItem(), listItem(paragraph(text("Delta"))))),
      ),
    )
  }

  // A new last text segment starting as the previous one did is another segment: no patch to it.
  @Test
  fun aNewLastTextSegmentRendersInFull() {
    val cache = TextRenderCache()
    val step = heading(2, "Step")
    val first = listOf(step, paragraph(text("Run this:")))

    fun renderAll(segments: List<MarkdownSegment>): List<RenderedSegment> {
      cache.begin(style)
      val rendered = MarkdownSegmentRenderer.render(segments, style, RuntimeEnvironment.getApplication(), null, null, cache = cache)
      cache.end()
      return rendered
    }
    renderAll(listOf(MarkdownSegment.Text(first)))
    renderAll(listOf(MarkdownSegment.Text(first), MarkdownSegment.CodeBlock(codeBlock("make"))))
    val last =
      renderAll(
        listOf(
          MarkdownSegment.Text(first),
          MarkdownSegment.CodeBlock(codeBlock("make")),
          MarkdownSegment.Text(listOf(step, paragraph(text("Then this")))),
        ),
      ).last() as RenderedSegment.Text

    assertNull(last.patch)
    assertNotNull(last.styledText)
  }
}
