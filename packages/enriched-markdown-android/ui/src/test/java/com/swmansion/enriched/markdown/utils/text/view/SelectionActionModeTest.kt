package com.swmansion.enriched.markdown.utils.text.view

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.view.ActionMode
import android.view.Menu
import android.widget.TextView
import androidx.appcompat.view.menu.MenuBuilder
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createEnrichedMarkdownTextSelectingText
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createEnrichedMarkdownTextWithSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewSelectingText
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithFullSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.createTextViewWithSelection
import com.swmansion.enriched.markdown.test.MarkdownTextViewTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.emphasis
import com.swmansion.enriched.markdown.test.TestAstFactory.image
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.strong
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class SelectionActionModeTest {
  private val context = ApplicationProvider.getApplicationContext<Context>()

  @Test
  fun copyAsMarkdownMenuItemAppearsWhenSelectionExists() {
    val textView =
      createTextViewSelectingText(
        document(paragraph(text("Copy me"))),
        "Copy me",
      )
    val menu = prepareMenu(textView)

    assertNotNull(findMenuItem(menu, "Copy as Markdown"))
  }

  @Test
  fun copyAsMarkdownMenuItemHiddenWhenDisabled() {
    val textView =
      createTextViewSelectingText(
        document(paragraph(text("Copy me"))),
        "Copy me",
      )
    val menu =
      prepareMenu(
        textView,
        SelectionMenuConfig(copyAsMarkdown = false),
      )

    assertNull(findMenuItem(menu, "Copy as Markdown"))
  }

  @Test
  fun copyAsMarkdownUsesCustomLabel() {
    val textView =
      createTextViewSelectingText(
        document(paragraph(text("Copy me"))),
        "Copy me",
      )
    val menu =
      prepareMenu(
        textView,
        SelectionMenuConfig(copyAsMarkdownLabel = "Export Markdown"),
      )

    assertNotNull(findMenuItem(menu, "Export Markdown"))
    assertNull(findMenuItem(menu, "Copy as Markdown"))
  }

  @Test
  fun clickingCopyAsMarkdownCopiesMarkdownToClipboard() {
    val textView =
      createTextViewSelectingText(
        document(
          paragraph(
            text("Value: "),
            strong(text("42")),
          ),
        ),
        "42",
      )
    val callback = createSelectionActionModeCallback(textView)
    val menu = prepareMenu(textView, callback = callback)
    val copyItem = findMenuItem(menu, "Copy as Markdown")

    assertTrue(callback.onActionItemClicked(null, copyItem))

    assertEquals("**42**", getClipboardText())
  }

  @Test
  fun clickingPlainCopyOnPlainTextViewCopiesPlainTextOnly() {
    val textView =
      createTextViewSelectingText(
        document(
          paragraph(
            text("Value: "),
            strong(text("42")),
          ),
        ),
        "42",
      )
    val callback = createSelectionActionModeCallback(textView)
    val menu = MenuBuilder(context)
    menu.add(0, android.R.id.copy, 0, "Copy")

    assertTrue(callback.onActionItemClicked(null, menu.findItem(android.R.id.copy)))

    assertEquals("42", getClipboardText())
    assertNull(getClipboardHtml())
  }

  @Test
  fun clickingPlainCopyOnEnrichedMarkdownTextCopiesPlainTextAndHtml() {
    val textView =
      createEnrichedMarkdownTextSelectingText(
        document(
          paragraph(
            text("Value: "),
            strong(text("42")),
          ),
        ),
        "42",
      )
    val callback = createSelectionActionModeCallback(textView)
    val menu = MenuBuilder(context)
    menu.add(0, android.R.id.copy, 0, "Copy")

    assertTrue(callback.onActionItemClicked(null, menu.findItem(android.R.id.copy)))

    assertEquals("42", getClipboardText())
    getClipboardHtml().let { html ->
      requireNotNull(html) { "Expected HTML clipboard content" }
      assertTrue("Expected <strong> in HTML but was: $html", html.contains("<strong") && html.contains("42"))
      assertTrue("Expected HTML wrapper but was: $html", html.startsWith("<html"))
    }
  }

  @Test
  fun clickingPlainCopyOnEnrichedMarkdownTextIncludesSemanticTagsForFormattedSelection() {
    val textView =
      createEnrichedMarkdownTextSelectingText(
        document(
          paragraph(
            text("Mix "),
            strong(text("bold")),
            text(" and "),
            emphasis(text("italic")),
          ),
        ),
        "bold",
      )
    val callback = createSelectionActionModeCallback(textView)
    val menu = MenuBuilder(context)
    menu.add(0, android.R.id.copy, 0, "Copy")

    assertTrue(callback.onActionItemClicked(null, menu.findItem(android.R.id.copy)))

    assertEquals("bold", getClipboardText())
    getClipboardHtml().let { html ->
      requireNotNull(html)
      assertTrue(html.contains("<strong") && html.contains("bold"))
    }
  }

  @Test
  fun clickingPlainCopyOnEnrichedMarkdownTextIncludesImageInHtml() {
    val url = "https://example.com/image.png"
    val spannable = render(document(paragraph(image(url))))
    val imageStart = spannable.indexOf('\uFFFC')
    val textView = createEnrichedMarkdownTextWithSelection(spannable, imageStart, imageStart + 1)

    val callback = createSelectionActionModeCallback(textView)
    val menu = MenuBuilder(context)
    menu.add(0, android.R.id.copy, 0, "Copy")

    assertTrue(callback.onActionItemClicked(null, menu.findItem(android.R.id.copy)))

    getClipboardHtml().let { html ->
      requireNotNull(html)
      assertTrue("Expected image URL in HTML but was: $html", html.contains("src=\"$url\""))
    }
  }

  @Test
  fun clickingPlainCopyDoesNothingForEmptySelection() {
    val spannable = render(document(paragraph(text("Hello"))))
    val textView = createTextViewWithSelection(spannable, 2, 2)
    val callback = createSelectionActionModeCallback(textView)
    val menu = MenuBuilder(context)
    menu.add(0, android.R.id.copy, 0, "Copy")

    assertTrue(callback.onActionItemClicked(null, menu.findItem(android.R.id.copy)))

    assertNull(getClipboardText())
    assertNull(getClipboardHtml())
  }

  @Test
  fun copyImageUrlMenuItemAppearsForHttpImageSelection() {
    val url = "https://example.com/image.png"
    val spannable = render(document(paragraph(image(url))))
    val imageStart = spannable.indexOf('\uFFFC')
    val textView = createTextViewWithSelection(spannable, imageStart, imageStart + 1)
    val menu = prepareMenu(textView)

    assertNotNull(findMenuItem(menu, "Copy Image URL"))
  }

  @Test
  fun copyImageUrlMenuItemHiddenWhenDisabled() {
    val url = "https://example.com/image.png"
    val spannable = render(document(paragraph(image(url))))
    val imageStart = spannable.indexOf('\uFFFC')
    val textView = createTextViewWithSelection(spannable, imageStart, imageStart + 1)
    val menu =
      prepareMenu(
        textView,
        SelectionMenuConfig(copyImageUrl = false),
      )

    assertNull(findMenuItem(menu, "Copy Image URL"))
  }

  @Test
  fun clickingCopyImageUrlCopiesUrlToClipboard() {
    val url = "https://example.com/image.png"
    val spannable = render(document(paragraph(image(url))))
    val imageStart = spannable.indexOf('\uFFFC')
    val textView = createTextViewWithSelection(spannable, imageStart, imageStart + 1)
    val callback = createSelectionActionModeCallback(textView)
    val menu = prepareMenu(textView, callback = callback)
    val copyUrlItem = findMenuItem(menu, "Copy Image URL")

    assertTrue(callback.onActionItemClicked(null, copyUrlItem))

    assertEquals(url, getClipboardText())
  }

  @Test
  fun copyImageUrlMenuShowsCountForMultipleImages() {
    val firstUrl = "https://example.com/first.png"
    val secondUrl = "https://example.com/second.png"
    val spannable =
      render(
        document(
          paragraph(
            image(firstUrl),
            text(" and "),
            image(secondUrl),
          ),
        ),
      )
    val textView = createTextViewWithFullSelection(spannable)
    val menu = prepareMenu(textView)

    assertNotNull(findMenuItem(menu, "Copy 2 Image URLs"))
  }

  @Test
  fun copyAsMarkdownDoesNothingForEmptySelection() {
    val spannable = render(document(paragraph(text("Hello"))))
    val textView = createTextViewWithSelection(spannable, 2, 2)
    val callback = createSelectionActionModeCallback(textView)
    val menu = prepareMenu(textView, callback = callback)

    assertNull(findMenuItem(menu, "Copy as Markdown"))
    assertFalse(copyMarkdownDirectly(textView))
    assertNull(getClipboardText())
  }

  private fun prepareMenu(
    textView: TextView,
    config: SelectionMenuConfig = SelectionMenuConfig(),
    callback: ActionMode.Callback =
      createSelectionActionModeCallback(
        textView,
        getSelectionMenuConfig = { config },
      ),
  ): Menu {
    val menu = MenuBuilder(context)
    callback.onPrepareActionMode(null, menu)
    return menu
  }

  private fun findMenuItem(
    menu: Menu,
    title: String,
  ) = (0 until menu.size()).map { menu.getItem(it) }.find { it.title.toString() == title }

  private fun getClipboardText(): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    return clipboard.primaryClip
      ?.getItemAt(0)
      ?.text
      ?.toString()
  }

  private fun getClipboardHtml(): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    return clipboard.primaryClip?.getItemAt(0)?.htmlText
  }

  private fun copyMarkdownDirectly(textView: TextView): Boolean {
    val markdown = MarkdownExtractor.getMarkdownForSelection(textView) ?: return false
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    clipboard.setPrimaryClip(ClipData.newPlainText("Markdown", markdown))
    return true
  }
}
