@file:OptIn(InternalPluginApi::class)

package com.swmansion.enriched.markdown.segments

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.Looper
import android.os.SystemClock
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.view.MotionEvent
import android.view.View
import android.widget.HorizontalScrollView
import android.widget.ImageButton
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.CodeBlockCopy
import com.swmansion.enriched.markdown.CodeBlockLayout
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.plugin.CodeBlockDecorator
import com.swmansion.enriched.markdown.plugin.InternalPluginApi
import com.swmansion.enriched.markdown.plugin.MarkdownPlugin
import com.swmansion.enriched.markdown.plugin.PluginRegistry
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.renderer.CodeBlockRenderer
import com.swmansion.enriched.markdown.styles.CodeBlockStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.renderSegments
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleWithCodeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.blockquote
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class CodeBlockSegmentTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  // Robolectric's text measurement is roughly a pixel per character, so the line has to be long in characters.
  private val longLine = "val answer = listOf(1, 2, 3).map { it * 2 }.filter { it > 2 }.joinToString(separator = \", \")".repeat(4)

  private fun fencedCodeBlock(
    content: String,
    language: String = "",
    fenceChar: String = "`",
  ) = MarkdownASTNode(
    NodeType.CodeBlock,
    attributes = mapOf("language" to language, "fenceChar" to fenceChar),
    children = listOf(text(content)),
  )

  private fun newView(
    node: MarkdownASTNode,
    codeBlockStyle: CodeBlockStyle = defaultStyle.codeBlockStyle,
  ): CodeBlockContainerView = CodeBlockContainerView(context, styleWithCodeBlock(codeBlockStyle)).apply { applyCodeBlockNode(node) }

  private fun layOut(
    view: View,
    width: Int,
  ) {
    view.measure(
      View.MeasureSpec.makeMeasureSpec(width, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)
  }

  private fun scrollViewOf(view: CodeBlockContainerView) = view.getChildAt(0) as HorizontalScrollView

  private fun textViewOf(view: CodeBlockContainerView) = scrollViewOf(view).getChildAt(0) as TextView

  private fun languageViewOf(view: CodeBlockContainerView) = view.getChildAt(1) as TextView

  private fun copyButtonOf(view: CodeBlockContainerView) = view.getChildAt(2) as ImageButton

  // A view posts its click on ACTION_UP, so it has to be attached for the click to run.
  private fun attach(view: View) {
    Robolectric
      .buildActivity(Activity::class.java)
      .setup()
      .get()
      .setContentView(view)
  }

  private fun tap(
    view: View,
    x: Float,
    y: Float,
  ) {
    val time = SystemClock.uptimeMillis()
    for (action in listOf(MotionEvent.ACTION_DOWN, MotionEvent.ACTION_UP)) {
      val event = MotionEvent.obtain(time, time, action, x, y, 0)
      view.dispatchTouchEvent(event)
      event.recycle()
    }
    shadowOf(Looper.getMainLooper()).idle()
  }

  private fun clipboardText(): String? =
    (context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager)
      .primaryClip
      ?.getItemAt(0)
      ?.text
      ?.toString()

  // A. Splitting and rendering

  @Test
  fun byDefaultARootCodeBlockStaysInItsTextSegment() {
    val doc = document(paragraph(text("Before")), codeBlock("val x = 1\n"), paragraph(text("After")))

    assertTrue(splitASTIntoSegments(doc, PluginSnapshot.EMPTY).single() is MarkdownSegment.Text)
    assertEquals(CodeBlockLayout.Wrapping, EnrichedMarkdown(context).codeBlockLayout)
  }

  @Test
  fun rootCodeBlockBecomesItsOwnSegmentInDocumentOrder() {
    val code = codeBlock("val x = 1\n")
    val doc = document(paragraph(text("Before")), code, paragraph(text("After")))

    val segments = splitASTIntoSegments(doc, PluginSnapshot.EMPTY, CodeBlockLayout.Scrollable)

    assertEquals(3, segments.size)
    assertTrue(segments[0] is MarkdownSegment.Text)
    assertEquals(code, (segments[1] as MarkdownSegment.CodeBlock).node)
    assertTrue(segments[2] is MarkdownSegment.Text)
  }

  @Test
  fun codeBlockNestedInListOrBlockquoteStaysInItsTextSegment() {
    val inList = document(unorderedList(listItem(paragraph(text("Item")), codeBlock("a\n"))))
    val inQuote = document(blockquote(codeBlock("b\n")))

    assertTrue(splitASTIntoSegments(inList, PluginSnapshot.EMPTY, CodeBlockLayout.Scrollable).single() is MarkdownSegment.Text)
    assertTrue(splitASTIntoSegments(inQuote, PluginSnapshot.EMPTY, CodeBlockLayout.Scrollable).single() is MarkdownSegment.Text)
  }

  @Test
  fun codeBlockSignatureIsStableForSameCodeAndDiffersFromOtherKinds() {
    val node = codeBlock("val x = 1\n")
    val signature = (renderSegments(listOf(MarkdownSegment.CodeBlock(node))).single() as RenderedSegment.CodeBlock).signature
    val again = (renderSegments(listOf(MarkdownSegment.CodeBlock(codeBlock("val x = 1\n")))).single()).signature
    val changed = (renderSegments(listOf(MarkdownSegment.CodeBlock(codeBlock("val x = 2\n")))).single()).signature
    val asText = (renderSegments(listOf(MarkdownSegment.Text(listOf(node)))).single()).signature

    assertEquals(signature, again)
    assertNotEquals(signature, changed)
    assertNotEquals(signature, asText)
  }

  @Test
  fun aPluginsCodeBlockRendererKeepsTheBlockInItsTextSegment() {
    val plugin =
      object : MarkdownPlugin {
        override val id = "code-renderer"

        override fun install(registry: PluginRegistry) =
          registry.registerNodeRenderer(NodeType.CodeBlock) { config, _ -> CodeBlockRenderer(config) }
      }
    val doc = document(paragraph(text("Before")), codeBlock("val x = 1\n"))

    assertTrue(splitASTIntoSegments(doc, PluginSnapshot.of(plugin), CodeBlockLayout.Scrollable).single() is MarkdownSegment.Text)
  }

  @Test
  fun aTopLevelBlockIsDecoratedOverItsCodeWithItsLanguage() {
    val calls = mutableListOf<Pair<String, String?>>()
    val decorator =
      CodeBlockDecorator { builder, start, end, language, _, _ ->
        calls += builder.subSequence(start, end).toString() to language
        builder.setSpan(ForegroundColorSpan(TOKEN_COLOR), start, start + 3, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    val plugins =
      PluginSnapshot.of(
        object : MarkdownPlugin {
          override val id = "decorating"

          override fun install(registry: PluginRegistry) = registry.registerCodeBlockDecorator(decorator)
        },
      )
    val segments =
      splitASTIntoSegments(document(fencedCodeBlock("val x = 1\n", language = "kotlin")), plugins, CodeBlockLayout.Scrollable)

    val rendered = MarkdownSegmentRenderer.render(segments, defaultStyle, context, plugins = plugins).single() as RenderedSegment.CodeBlock
    val view = CodeBlockContainerView(context, defaultStyle).apply { applyCodeBlockNode(rendered.node, rendered.text) }

    assertEquals(listOf("val x = 1" to "kotlin"), calls)
    val shown = textViewOf(view).text as Spanned
    assertEquals(TOKEN_COLOR, shown.getSpans(0, 3, ForegroundColorSpan::class.java).single().foregroundColor)
  }

  /** Parsing is native, so this starts from the AST; from there it runs the view's own render and landing. */
  @Test
  fun aScrollingViewShowsItsTopLevelBlockDecoratedByItsPlugins() {
    val decorator =
      CodeBlockDecorator { builder, start, _, _, _, _ ->
        builder.setSpan(ForegroundColorSpan(TOKEN_COLOR), start, start + 3, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    val view =
      EnrichedMarkdown(context).apply {
        setPlugins(
          listOf(
            object : MarkdownPlugin {
              override val id = "decorating"

              override fun install(registry: PluginRegistry) = registry.registerCodeBlockDecorator(decorator)
            },
          ),
        )
        setCodeBlockLayout(CodeBlockLayout.Scrollable)
      }

    view.applyRenderedSegments(view.segmentRenderer()(document(fencedCodeBlock("val x = 1\n", language = "kotlin"))))

    val shown = textViewOf(view.getChildAt(0) as CodeBlockContainerView).text as Spanned
    assertEquals("val x = 1", shown.toString())
    assertEquals(TOKEN_COLOR, shown.getSpans(0, 3, ForegroundColorSpan::class.java).single().foregroundColor)
  }

  @Test
  fun withNoPluginsTheBlockShowsItsPlainCode() {
    val segments = splitASTIntoSegments(document(fencedCodeBlock("val x = 1\n")), PluginSnapshot.EMPTY, CodeBlockLayout.Scrollable)
    val rendered = renderSegments(segments).single() as RenderedSegment.CodeBlock

    assertEquals("val x = 1", rendered.text.toString())
    assertTrue((rendered.text as Spanned).getSpans(0, rendered.text.length, ForegroundColorSpan::class.java).isEmpty())
  }

  // B. Layout

  @Test
  fun longLinesDoNotWrapSoHeightIsIndependentOfWidth() {
    val view = newView(fencedCodeBlock("$longLine\nshort\n"))

    layOut(view, 2000)
    val wideHeight = view.measuredHeight
    layOut(view, 200)

    assertEquals(wideHeight, view.measuredHeight)
    assertEquals(2, textViewOf(view).layout.lineCount)
  }

  @Test
  fun codeWiderThanTheBoxScrollsHorizontally() {
    val view = newView(fencedCodeBlock(longLine))
    layOut(view, 200)

    val scrollView = scrollViewOf(view)
    assertTrue(textViewOf(view).width > scrollView.width)
    assertTrue(scrollView.canScrollHorizontally(1))

    scrollView.scrollTo(50, 0)
    assertTrue(scrollView.canScrollHorizontally(-1))
  }

  @Test
  fun boxFillsTheGivenWidthWhenTheCodeIsShort() {
    val view = newView(fencedCodeBlock("x"))
    layOut(view, 1000)

    assertEquals(1000, view.width)
    assertTrue(!scrollViewOf(view).canScrollHorizontally(1))
  }

  @Test
  fun shortCodeFillsTheBoxSoALongPressAnywhereReachesTheTextView() {
    val view = newView(fencedCodeBlock("x"))
    layOut(view, 1000)

    val scrollView = scrollViewOf(view)
    val textView = textViewOf(view)
    assertEquals(scrollView.width, textView.width)
    assertEquals(scrollView.height, textView.height)
    assertTrue(textView.isLongClickable)
  }

  @Test
  fun codeBlockLineHeightSpacesTheLines() {
    val code = fencedCodeBlock("line 1\nline 2\nline 3")
    val plain = newView(code, defaultStyle.codeBlockStyle.copy(lineHeight = 0f))
    val spaced = newView(code, defaultStyle.codeBlockStyle.copy(lineHeight = 100f))
    layOut(plain, 1000)
    layOut(spaced, 1000)

    val plainLayout = textViewOf(plain).layout
    val spacedLayout = textViewOf(spaced).layout
    assertTrue(plainLayout.getLineBottom(0) < 100)
    for (line in 0 until 3) {
      assertEquals(100, spacedLayout.getLineBottom(line) - spacedLayout.getLineTop(line))
    }
    assertEquals(spacedLayout.height - plainLayout.height, spaced.measuredHeight - plain.measuredHeight)
  }

  @Test
  fun wrapContentParentShrinksTheBoxToTheCode() {
    val view = newView(fencedCodeBlock("x"))
    view.measure(
      View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.AT_MOST),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )

    assertTrue(view.measuredWidth < 1000)
  }

  @Test
  fun codeStartsAtTheLeftInRtl() {
    val view = newView(fencedCodeBlock(longLine))
    view.layoutDirection = View.LAYOUT_DIRECTION_RTL
    layOut(view, 200)

    assertEquals(0, scrollViewOf(view).scrollX)
  }

  @Test
  fun reapplyingANodeKeepsTheScrollPosition() {
    val view = newView(fencedCodeBlock(longLine))
    layOut(view, 200)
    scrollViewOf(view).scrollTo(50, 0)

    view.applyCodeBlockNode(fencedCodeBlock("$longLine\nmore"))
    layOut(view, 200)

    assertEquals(50, scrollViewOf(view).scrollX)
  }

  @Test
  fun headerSitsAboveTheCode() {
    val view = newView(fencedCodeBlock("x", language = "kotlin"))
    layOut(view, 1000)

    val scrollView = scrollViewOf(view)
    // Robolectric's text metrics make the label taller than on a device, so compare centers:
    // both header views are centered above the code.
    assertTrue(scrollView.top > 0)
    assertTrue((languageViewOf(view).top + languageViewOf(view).bottom) / 2 < scrollView.top)
    assertTrue((copyButtonOf(view).top + copyButtonOf(view).bottom) / 2 < scrollView.top)
    assertTrue(copyButtonOf(view).left > languageViewOf(view).right)
    assertEquals(view.height, scrollView.bottom + defaultStyle.codeBlockStyle.borderWidth.toInt())
  }

  @Test
  fun wrapContentParentKeepsRoomForTheHeader() {
    val view = newView(fencedCodeBlock("x", language = "kotlin"))
    view.measure(
      View.MeasureSpec.makeMeasureSpec(1000, View.MeasureSpec.AT_MOST),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, view.measuredWidth, view.measuredHeight)

    assertTrue(copyButtonOf(view).left >= languageViewOf(view).right)
    assertTrue(copyButtonOf(view).right <= view.width)
  }

  @Test
  fun segmentMarginsComeFromTheCodeBlockStyle() {
    val view = newView(fencedCodeBlock("x"))

    assertEquals(defaultStyle.codeBlockStyle.marginTop.toInt(), view.segmentMarginTop)
    assertEquals(defaultStyle.codeBlockStyle.marginBottom.toInt(), view.segmentMarginBottom)
  }

  // C. Content and copy output

  @Test
  fun showsTheCodeWithoutTheTrailingNewline() {
    val view = newView(fencedCodeBlock("line 1\nline 2\n"))

    assertEquals("line 1\nline 2", textViewOf(view).text.toString())
  }

  @Test
  fun headerShowsTheFenceLanguage() {
    val view = newView(fencedCodeBlock("x", language = "kotlin"))

    // The native display-name lookup is unavailable under Robolectric, so the raw fence string shows.
    assertEquals("kotlin", languageViewOf(view).text.toString())

    view.applyCodeBlockNode(fencedCodeBlock("x"))
    assertEquals("", languageViewOf(view).text.toString())
  }

  @Test
  fun copyButtonCopiesTheCode() {
    val view = newView(fencedCodeBlock("line 1\nline 2\n", language = "kotlin"))

    copyButtonOf(view).performClick()

    assertEquals("line 1\nline 2", clipboardText())
  }

  @Test
  fun copyButtonTakesTapsAroundItOverTheCode() {
    val view = newView(fencedCodeBlock("line 1\nline 2\n", language = "kotlin"))
    attach(view)
    layOut(view, 1000)
    val button = copyButtonOf(view)
    val minTouchTarget = 48 * context.resources.displayMetrics.density
    val belowButton = (button.top + button.bottom) / 2f + minTouchTarget / 2 - 1

    assertTrue(belowButton > scrollViewOf(view).top)
    tap(view, button.left + button.width / 2f, belowButton)

    assertEquals("line 1\nline 2", clipboardText())
  }

  @Test
  fun tapsAwayFromTheCopyButtonDoNotCopy() {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Previous", "previous"))
    val view = newView(fencedCodeBlock("line 1\nline 2\n", language = "kotlin"))
    attach(view)
    layOut(view, 1000)

    tap(view, 10f, view.height - 10f)

    assertEquals("previous", clipboardText())
  }

  @Test
  fun copyButtonLeavesTheClipboardAloneForAnEmptyBlock() {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Previous", "previous"))
    val view = newView(fencedCodeBlock(""))
    val copies = mutableListOf<CodeBlockCopy>()
    view.onCodeBlockCopy = { copies += it }

    copyButtonOf(view).performClick()

    assertEquals("previous", clipboardText())
    assertEquals(emptyList<CodeBlockCopy>(), copies)
  }

  @Test
  fun copyButtonReportsTheCodeAndTheFenceLanguage() {
    val view = newView(fencedCodeBlock("line 1\nline 2\n", language = "kotlin"))
    val copies = mutableListOf<CodeBlockCopy>()
    view.onCodeBlockCopy = { copies += it }

    copyButtonOf(view).performClick()
    view.applyCodeBlockNode(fencedCodeBlock("x"))
    copyButtonOf(view).performClick()

    assertEquals(listOf(CodeBlockCopy("line 1\nline 2", "kotlin"), CodeBlockCopy("x", null)), copies)
  }

  @Test
  fun theViewsCopyCallbackReachesBlocksRenderedBeforeAndAfterItIsSet() {
    val view = EnrichedMarkdown(context).apply { setCodeBlockLayout(CodeBlockLayout.Scrollable) }
    val render = view.segmentRenderer()
    val before = mutableListOf<CodeBlockCopy>()
    val after = mutableListOf<CodeBlockCopy>()

    view.setOnCodeBlockCopyCallback { before += it }
    view.applyRenderedSegments(render(document(fencedCodeBlock("a"))))
    copyButtonOf(view.getChildAt(0) as CodeBlockContainerView).performClick()

    view.setOnCodeBlockCopyCallback { after += it }
    copyButtonOf(view.getChildAt(0) as CodeBlockContainerView).performClick()

    assertEquals(listOf(CodeBlockCopy("a", null)), before)
    assertEquals(listOf(CodeBlockCopy("a", null)), after)
  }

  @Test
  fun fencedMarkdownKeepsLanguageAndFenceChar() {
    assertEquals("```kotlin\nval x = 1\n```", CodeBlockContainerView.fencedMarkdown("val x = 1", "kotlin", '`'))
    assertEquals("~~~\nx\n~~~", CodeBlockContainerView.fencedMarkdown("x", null, '~'))
  }

  @Test
  fun fencedMarkdownOutgrowsAFenceInsideTheCode() {
    val markdown = CodeBlockContainerView.fencedMarkdown("```\nnested\n```", "md", '`')

    assertEquals("````md\n```\nnested\n```\n````", markdown)
  }

  private companion object {
    const val TOKEN_COLOR = 0xFF123456.toInt()
  }
}
