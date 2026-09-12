package com.swmansion.enriched.markdown.test

import android.content.Context
import android.text.Selection
import android.text.Spannable
import android.text.SpannableString
import android.widget.TextView
import androidx.test.core.app.ApplicationProvider
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode

object MarkdownTextViewTestSupport {
  private val context: Context = ApplicationProvider.getApplicationContext()

  fun render(document: MarkdownASTNode): SpannableString = MarkdownRenderTestSupport.render(document)

  fun createTextViewWithSelection(
    spannable: SpannableString,
    selectionStart: Int,
    selectionEnd: Int,
  ): TextView {
    val textView = TextView(context)
    applySelection(textView, spannable, selectionStart, selectionEnd)
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

  fun createEnrichedMarkdownTextWithSelection(
    spannable: SpannableString,
    selectionStart: Int,
    selectionEnd: Int,
  ): EnrichedMarkdownText {
    val textView = EnrichedMarkdownText(context)
    applySelection(textView, spannable, selectionStart, selectionEnd)
    return textView
  }

  fun createEnrichedMarkdownTextSelectingText(
    document: MarkdownASTNode,
    selectedText: String,
  ): EnrichedMarkdownText {
    val spannable = render(document)
    val start = indexOf(spannable, selectedText)
    return createEnrichedMarkdownTextWithSelection(spannable, start, start + selectedText.length)
  }

  fun createEnrichedMarkdownTextWithFullSelection(document: MarkdownASTNode): EnrichedMarkdownText {
    val spannable = render(document)
    return createEnrichedMarkdownTextWithSelection(spannable, 0, spannable.length)
  }

  fun createEnrichedMarkdownTextWithStoredMarkdown(
    originalMarkdown: String,
    rendered: SpannableString,
  ): EnrichedMarkdownText {
    val textView = createEnrichedMarkdownTextWithSelection(rendered, 0, rendered.length)
    setCurrentMarkdown(textView, originalMarkdown)
    return textView
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

  private fun applySelection(
    textView: TextView,
    spannable: SpannableString,
    selectionStart: Int,
    selectionEnd: Int,
  ) {
    textView.setTextIsSelectable(true)
    if (textView is EnrichedMarkdownText) {
      textView.text = spannable
    } else {
      textView.setText(spannable, TextView.BufferType.SPANNABLE)
    }
    Selection.setSelection(textView.text as Spannable, selectionStart, selectionEnd)
  }

  /** Mirrors what [EnrichedMarkdownText.setMarkdownContent] stores, without the async render. */
  private fun setCurrentMarkdown(
    textView: EnrichedMarkdownText,
    markdown: String,
  ) {
    val field = EnrichedMarkdownText::class.java.getDeclaredField("baseMarkdown")
    field.isAccessible = true
    field.set(textView, markdown)
  }
}
