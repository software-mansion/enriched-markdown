package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.Selection
import android.text.Spannable
import android.text.SpannableString
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.EnrichedMarkdown
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.segments.RenderedSegment
import com.swmansion.enriched.markdown.segments.SegmentSignature

object MarkdownTextViewTestSupport {
  private val context: Context = ApplicationProvider.getApplicationContext()

  fun render(document: MarkdownASTNode): SpannableString = MarkdownRenderTestSupport.render(document)

  fun createTextViewWithSelection(
    spannable: SpannableString,
    selectionStart: Int,
    selectionEnd: Int,
  ): TextView {
    val textView = TextView(context)
    textView.setTextIsSelectable(true)
    textView.setText(spannable, TextView.BufferType.SPANNABLE)
    Selection.setSelection(textView.text as Spannable, selectionStart, selectionEnd)
    return textView
  }

  fun createTextViewWithSelection(
    document: MarkdownASTNode,
    selectionStart: Int,
    selectionEnd: Int,
  ): TextView = createTextViewWithSelection(render(document), selectionStart, selectionEnd)

  fun createTextViewWithFullSelection(spannable: SpannableString): TextView = createTextViewWithSelection(spannable, 0, spannable.length)

  fun createTextViewWithFullSelection(document: MarkdownASTNode): TextView {
    val spannable = render(document)
    return createTextViewWithFullSelection(spannable)
  }

  fun createTextViewSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
  ): TextView {
    val spannable = render(document)
    val start = indexOf(spannable, selectedText)
    return createTextViewWithSelection(spannable, start, start + selectedText.length)
  }

  /**
   * Builds a fresh [EnrichedMarkdown] container, attaches [spannable] as its sole
   * child the production way (via `applyRenderedSegments`), and applies the given
   * selection to that child. Returns the child, which is left attached to the
   * container so the parent-walking production code (`SelectionActionMode`,
   * `MarkdownExtractor`) sees a real ancestor.
   */
  fun createEnrichedMarkdownTextWithSelection(
    spannable: SpannableString,
    selectionStart: Int,
    selectionEnd: Int,
  ): EnrichedMarkdownInternalText {
    val textView = attachSoleChild(spannable)
    Selection.setSelection(textView.text as Spannable, selectionStart, selectionEnd)
    return textView
  }

  fun createEnrichedMarkdownTextSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
  ): EnrichedMarkdownInternalText {
    val spannable = render(document)
    val start = indexOf(spannable, selectedText)
    return createEnrichedMarkdownTextWithSelection(spannable, start, start + selectedText.length)
  }

  fun createEnrichedMarkdownTextWithFullSelection(document: MarkdownASTNode): EnrichedMarkdownInternalText {
    val spannable = render(document)
    return createEnrichedMarkdownTextWithSelection(spannable, 0, spannable.length)
  }

  fun createEnrichedMarkdownTextWithStoredMarkdown(
    originalMarkdown: String,
    rendered: SpannableString,
  ): EnrichedMarkdownInternalText {
    val textView = createEnrichedMarkdownTextWithSelection(rendered, 0, rendered.length)
    setCurrentMarkdown(textView.parent as EnrichedMarkdown, originalMarkdown)
    return textView
  }

  /**
   * Same as [createEnrichedMarkdownTextWithStoredMarkdown], but returns the
   * container instead of its sole child, for tests that need the
   * document-level API (`setMarkdownContent`, `currentMarkdown`,
   * `setOnTaskListItemPressCallback`, ...).
   */
  fun createContainerWithStoredMarkdown(
    originalMarkdown: String,
    rendered: SpannableString,
  ): EnrichedMarkdown {
    val textView = createEnrichedMarkdownTextWithSelection(rendered, 0, rendered.length)
    val container = textView.parent as EnrichedMarkdown
    setCurrentMarkdown(container, originalMarkdown)
    return container
  }

  fun selectedRange(
    spannable: SpannableString,
    start: Int,
    end: Int,
  ): Spannable = spannable.subSequence(start, end) as Spannable

  fun indexOf(
    spannable: Spannable,
    text: String,
  ): Int {
    val index = spannable.indexOf(text)
    require(index >= 0) { "Rendered text does not contain \"$text\": \"$spannable\"" }
    return index
  }

  private fun attachSoleChild(spannable: SpannableString): EnrichedMarkdownInternalText {
    val container = EnrichedMarkdown(context)
    val segment =
      RenderedSegment.Text(
        styledText = spannable,
        imageSpans = emptyList(),
        needsJustify = false,
        lastElementMarginBottom = 0f,
        signature = SegmentSignature.signatureForNodes(emptyList()) xor SegmentSignature.TEXT_KIND_SALT,
      )
    container.applyRenderedSegments(listOf(segment))
    return container.getChildAt(0) as EnrichedMarkdownInternalText
  }

  /** Mirrors what [EnrichedMarkdown.setMarkdownContent] stores, without the async render. */
  private fun setCurrentMarkdown(
    container: EnrichedMarkdown,
    markdown: String,
  ) {
    val field = EnrichedMarkdown::class.java.getDeclaredField("baseMarkdown")
    field.isAccessible = true
    field.set(container, markdown)
  }
}
