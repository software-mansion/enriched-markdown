package com.swmansion.enriched.markdown

import android.text.Editable
import android.text.Selection
import android.text.Spannable
import android.text.TextWatcher
import android.view.View.MeasureSpec
import android.view.ViewGroup
import android.widget.ScrollView
import android.widget.TextView
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.segments.MarkdownSegment
import com.swmansion.enriched.markdown.segments.MarkdownSegmentRenderer
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentViewCreators
import com.swmansion.enriched.markdown.segments.TextRenderCache
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// A patched view must lay out as one given the whole text: DynamicLayout reflows only when the
// watchers it registered hear of the edit (InsertionOrderedSpannable's watcher proxies), which
// rests on how DynamicLayout and TextView listen: checked on every API level native graphics run on.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [26, 28, 30, 33, 35])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class TextTailPatchTest {
  private val context = RuntimeEnvironment.getApplication()
  private val style = styleConfig()

  private val words = "streamed text that wraps over several lines of the view as it keeps on growing".split(" ")

  // A paragraph growing a word at a time, then a list after it.
  private val states: List<List<MarkdownASTNode>> =
    (1..words.size).map { listOf(paragraph(text(words.take(it).joinToString(" ")))) } +
      (1..words.size).map { count ->
        listOf(
          paragraph(text(words.joinToString(" "))),
          unorderedList(listItem(paragraph(text("first item"))), listItem(paragraph(text(words.take(count).joinToString(" "))))),
        )
      }

  private fun render(
    nodes: List<MarkdownASTNode>,
    cache: TextRenderCache?,
  ): RenderedSegment.Text {
    cache?.begin(style)
    val rendered =
      MarkdownSegmentRenderer.render(listOf(MarkdownSegment.Text(nodes)), style, context, null, null, cache = cache)
    cache?.end()
    return rendered.single() as RenderedSegment.Text
  }

  private fun newView() =
    EnrichedMarkdownInternalText(context).apply {
      layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
    }

  private fun layOut(view: TextView) {
    view.measure(
      MeasureSpec.makeMeasureSpec(WIDTH, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  @Test
  fun aPatchedViewLaysOutAsTheWholeText() {
    val cache = TextRenderCache()
    val view = newView()
    var patches = 0
    for (state in states) {
      val segment = render(state, cache)
      val patch = segment.patch
      if (patch != null && view.renderedRevision == patch.baseRevision && view.applyStyledTextPatch(patch.start, patch.tail)) {
        patches++
      } else {
        view.applyStyledText(segment.styledText!!)
      }
      view.renderedRevision = segment.revision
      layOut(view)

      val fresh = newView().apply { applyStyledText(render(state, null).styledText!!) }
      layOut(fresh)
      assertEquals(fresh.text.toString(), view.text.toString())
      assertEquals(fresh.layout.lineCount, view.layout.lineCount)
      assertEquals(fresh.measuredHeight, view.measuredHeight)
    }
    // A text of one node renders in full: only the list's growth patches.
    assertTrue("patched $patches of ${states.size}", patches >= words.size - 1)
  }

  @Test
  fun aViewWithoutThePatchBaseKeepsItsTextAndAsksForAFullRender() {
    val cache = TextRenderCache()
    render(states[words.size], cache)
    val patchOnly = render(states[words.size + 1], cache)
    assertNull(patchOnly.styledText)

    val view = newView().apply { applyStyledText(render(states[0], null).styledText!!) }
    val before = view.text.toString()
    SegmentViewCreators.updateTextView(view, patchOnly)
    assertEquals(before, view.text.toString())
    assertEquals(listOf(0), SegmentViewCreators.syncTextRevisions(listOf(patchOnly), listOf(view)))
  }

  // After the cache was dropped (a synchronous render), the next full render hands the reconciler
  // the same segment under a new revision, and it keeps the view: the next patch must still apply.
  @Test
  fun aKeptViewTakesTheNewRevisionSoTheNextPatchApplies() {
    val cache = TextRenderCache()
    val view = newView()
    val first = render(states[words.size], cache)
    SegmentViewCreators.updateTextView(view, first)

    cache.clear()
    val again = render(states[words.size], cache)
    assertNotEquals(first.revision, again.revision)
    assertEquals(first.signature, again.signature)
    // Kept, not updated: same signature.
    assertEquals(emptyList<Int>(), SegmentViewCreators.syncTextRevisions(listOf(again), listOf(view)))
    assertEquals(again.revision, view.renderedRevision)

    val patch = render(states[words.size + 1], cache)
    SegmentViewCreators.updateTextView(view, patch)
    assertEquals(emptyList<Int>(), SegmentViewCreators.syncTextRevisions(listOf(patch), listOf(view)))
    assertEquals(render(states[words.size + 1], null).styledText.toString(), view.text.toString())
  }

  // A patch is not a user edit: TextView must not scroll to its selection (always there in a
  // selectable view) nor move one the user made in the text before the edit.
  @Test
  fun aPatchKeepsTheScrollPositionAndTheSelection() {
    val cache = TextRenderCache()
    val view = newView()
    val scroll = ScrollView(context).apply { addView(view) }
    SegmentViewCreators.updateTextView(view, render(states[words.size], cache))
    layOutScroll(scroll)
    scroll.scrollTo(0, view.height)
    val scrolled = scroll.scrollY
    assertTrue(scrolled > 0)
    // A tap focuses a selectable view; a focused TextView scrolls its parent to the selection.
    assertTrue(view.requestFocus())
    Selection.setSelection(view.text as Spannable, 2, 6)

    SegmentViewCreators.updateTextView(view, render(states[words.size + 1], cache))
    layOutScroll(scroll)
    assertEquals(scrolled, scroll.scrollY)
    assertEquals(2, view.selectionStart)
    assertEquals(6, view.selectionEnd)
  }

  // TextView's Editor keeps state over the text it last heard of: a word selected past the end of
  // that text threw while the view kept streaming. A patch must reach TextView's own watcher, which
  // tells the Editor and the view's text listeners.
  @Test
  fun aPatchReachesTextViewsOwnWatcher() {
    val cache = TextRenderCache()
    val view = newView()
    SegmentViewCreators.updateTextView(view, render(states[words.size], cache))
    layOut(view)
    val changes = mutableListOf<List<Int>>()
    view.addTextChangedListener(
      object : TextWatcher {
        override fun beforeTextChanged(
          text: CharSequence?,
          start: Int,
          count: Int,
          after: Int,
        ) = Unit

        override fun onTextChanged(
          text: CharSequence?,
          start: Int,
          before: Int,
          count: Int,
        ) {
          changes += listOf(start, before, count)
        }

        override fun afterTextChanged(text: Editable?) = Unit
      },
    )
    val before = view.text.length

    SegmentViewCreators.updateTextView(view, render(states[words.size + 1], cache))

    val (start, removed, added) = changes.single()
    assertEquals(before, start + removed)
    assertEquals(view.text.length, start + added)
  }

  private fun layOutScroll(scroll: ScrollView) {
    scroll.measure(
      MeasureSpec.makeMeasureSpec(WIDTH, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(SCROLL_HEIGHT, MeasureSpec.EXACTLY),
    )
    scroll.layout(0, 0, WIDTH, SCROLL_HEIGHT)
  }

  private companion object {
    const val WIDTH = 300
    const val SCROLL_HEIGHT = 40
  }
}
