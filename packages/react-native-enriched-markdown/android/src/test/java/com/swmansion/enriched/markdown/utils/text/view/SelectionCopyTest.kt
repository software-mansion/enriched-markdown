package com.swmansion.enriched.markdown.utils.text.view

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.os.TransactionTooLargeException
import android.text.Selection
import android.text.Spannable
import android.text.SpannableString
import android.text.Spanned
import android.view.ActionMode
import android.view.KeyEvent
import android.view.Menu
import android.view.MenuInflater
import android.view.View
import androidx.appcompat.view.menu.MenuBuilder
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.spans.ImageSpan
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.Implementation
import org.robolectric.annotation.Implements
import org.robolectric.shadows.ShadowClipboardManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class SelectionCopyTest {
  private data class Copy(
    val text: String,
    val format: SelectionCopyFormat,
    val start: Int,
    val end: Int,
  )

  private val context: Context
    get() = RuntimeEnvironment.getApplication()

  // "Value: 42", with "42" in bold.
  private fun segmentSelecting(
    start: Int,
    end: Int,
  ): Pair<EnrichedMarkdownInternalText, MutableList<Copy>> {
    val style = MarkdownRenderTestSupport.styleConfig()
    val strong = MarkdownASTNode(NodeType.Strong, children = listOf(text("42")))
    val view = EnrichedMarkdownInternalText(context)
    view.applyStyledText(MarkdownRenderTestSupport.render(style, paragraph(text("Value: "), strong)))
    Selection.setSelection(view.text as Spannable, start, end)
    val copies = mutableListOf<Copy>()
    view.onSelectionCopyCallback = { text, format, s, e -> copies += Copy(text, format, s, e) }
    return view to copies
  }

  // A style is what makes Copy add HTML to the clip.
  private fun styledTextSelecting(
    start: Int,
    end: Int,
  ): Pair<EnrichedMarkdownText, MutableList<Copy>> {
    val view = EnrichedMarkdownText(context)
    view.setMarkdownStyle(MarkdownRenderTestSupport.exportStyleMap())
    view.setTextIsSelectable(true)
    view.text = "Hello world"
    Selection.setSelection(view.text as Spannable, start, end)
    val copies = mutableListOf<Copy>()
    view.onSelectionCopyCallback = { text, format, s, e -> copies += Copy(text, format, s, e) }
    return view to copies
  }

  // The system adds Copy; the callback adds the rest in onPrepareActionMode.
  // Like the platform's Editor, sends what the callback doesn't handle to onTextContextMenuItem.
  private fun clickMenuItem(
    view: android.widget.TextView,
    title: String,
    toolbar: ActionMode? = null,
  ) {
    val menu = MenuBuilder(context)
    menu.add(Menu.NONE, android.R.id.copy, Menu.NONE, "Copy")
    val callback = view.customSelectionActionModeCallback!!
    callback.onPrepareActionMode(toolbar, menu)
    val item = (0 until menu.size()).map(menu::getItem).first { it.title == title }
    assertTrue(callback.onActionItemClicked(toolbar, item) || view.onTextContextMenuItem(item.itemId))
  }

  private fun pressCtrlC(view: android.widget.TextView): Boolean =
    view.onKeyShortcut(
      KeyEvent.KEYCODE_C,
      KeyEvent(0, 0, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_C, 0, KeyEvent.META_CTRL_ON),
    )

  private fun clipboardText(): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    return clipboard.primaryClip
      ?.getItemAt(0)
      ?.text
      ?.toString()
  }

  private fun clipboardHtml(): String? {
    val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
    return clipboard.primaryClip?.getItemAt(0)?.htmlText
  }

  @After
  fun acceptEveryClip() {
    RefusingClipboard.refuses = { false }
  }

  @Test
  fun menuCopyReportsPlainText() {
    val (view, copies) = segmentSelecting(7, 9)
    clickMenuItem(view, "Copy")

    assertEquals(listOf(Copy("42", SelectionCopyFormat.PLAIN, 7, 9)), copies)
    assertEquals("42", clipboardText())
  }

  @Test
  fun menuCopyAsMarkdownReportsMarkdown() {
    val (view, copies) = segmentSelecting(7, 9)
    view.selectionMenuConfig = SelectionMenuConfig(copyAsMarkdownLabel = "Copy as Markdown")
    clickMenuItem(view, "Copy as Markdown")

    assertEquals(listOf(Copy("**42**", SelectionCopyFormat.MARKDOWN, 7, 9)), copies)
    assertEquals("**42**", clipboardText())
  }

  @Test
  fun ctrlCReportsPlainText() {
    val (view, copies) = segmentSelecting(7, 9)

    assertTrue(pressCtrlC(view))

    assertEquals(listOf(Copy("42", SelectionCopyFormat.PLAIN, 7, 9)), copies)
    assertEquals("42", clipboardText())
  }

  @Test
  fun ctrlCCopiesABackwardSelection() {
    val (view, copies) = segmentSelecting(9, 7)

    assertTrue(pressCtrlC(view))

    assertEquals(listOf(Copy("42", SelectionCopyFormat.PLAIN, 7, 9)), copies)
    assertEquals("42", clipboardText())
  }

  @Test
  fun ctrlCOnEnrichedMarkdownTextReportsPlainText() {
    val view = EnrichedMarkdownText(context)
    view.setTextIsSelectable(true)
    view.text = "Hello world"
    Selection.setSelection(view.text as Spannable, 6, 11)
    val copies = mutableListOf<Copy>()
    view.onSelectionCopyCallback = { text, format, s, e -> copies += Copy(text, format, s, e) }

    assertTrue(pressCtrlC(view))

    assertEquals(listOf(Copy("world", SelectionCopyFormat.PLAIN, 6, 11)), copies)
    assertEquals("world", clipboardText())
  }

  @Test
  fun emptySelectionReportsNothing() {
    val (view, copies) = segmentSelecting(3, 3)
    clickMenuItem(view, "Copy")

    assertEquals(emptyList<Copy>(), copies)
  }

  @Test
  fun menuCopyOnEnrichedMarkdownTextReportsPlainText() {
    val (view, copies) = styledTextSelecting(6, 11)
    clickMenuItem(view, "Copy")

    assertEquals(listOf(Copy("world", SelectionCopyFormat.PLAIN, 6, 11)), copies)
    assertEquals("world", clipboardText())
  }

  @Test
  fun menuCopyImageUrlReportsTheUrl() {
    val url = "https://example.com/forest.png"
    val styled = SpannableString("a￼b")
    val style = StyleConfig(MarkdownRenderTestSupport.exportStyleMap(), context, false, 0f)
    val image = ImageSpan(context, url, style)
    styled.setSpan(image, 1, 2, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
    val view = EnrichedMarkdownInternalText(context)
    view.applyStyledText(styled)
    Selection.setSelection(view.text as Spannable, 0, 3)
    val copies = mutableListOf<Copy>()
    view.onSelectionCopyCallback = { text, format, s, e -> copies += Copy(text, format, s, e) }
    view.selectionMenuConfig = SelectionMenuConfig(copyImageUrlLabel = "Copy Image URL")

    clickMenuItem(view, "Copy Image URL")

    assertEquals(listOf(Copy(url, SelectionCopyFormat.IMAGE_URLS, 0, 3)), copies)
    assertEquals(url, clipboardText())
  }

  @Test
  fun ctrlCOnAStyledViewCopiesHtmlToo() {
    val (view, copies) = styledTextSelecting(6, 11)

    assertTrue(pressCtrlC(view))

    assertEquals(listOf(Copy("world", SelectionCopyFormat.PLAIN, 6, 11)), copies)
    assertEquals("world", clipboardText())
    assertTrue(clipboardHtml()!!.contains("world"))
  }

  @Test
  fun ctrlCClosesTheSelectionToolbar() {
    val (view, _) = segmentSelecting(7, 9)
    val toolbar = FakeActionMode()
    view.customSelectionActionModeCallback!!.onCreateActionMode(toolbar, MenuBuilder(context))

    assertTrue(pressCtrlC(view))

    assertTrue(toolbar.finished)
  }

  @Test
  fun menuItemsCloseTheSelectionToolbar() {
    val (view, _) = segmentSelecting(7, 9)
    view.selectionMenuConfig = SelectionMenuConfig(copyAsMarkdownLabel = "Copy as Markdown")

    for (title in listOf("Copy", "Copy as Markdown")) {
      val toolbar = FakeActionMode()
      view.customSelectionActionModeCallback!!.onCreateActionMode(toolbar, MenuBuilder(context))

      clickMenuItem(view, title, toolbar)

      assertTrue(title, toolbar.finished)
    }
  }

  @Test
  fun ctrlCLeavesAFinishedToolbarAlone() {
    val (view, _) = segmentSelecting(7, 9)
    val toolbar = FakeActionMode()
    val callback = view.customSelectionActionModeCallback!!
    callback.onCreateActionMode(toolbar, MenuBuilder(context))
    callback.onDestroyActionMode(toolbar)

    assertTrue(pressCtrlC(view))

    assertFalse(toolbar.finished)
  }

  @Test
  @Config(shadows = [RefusingClipboard::class])
  fun ctrlCDropsTheHtmlWhenTheClipboardRefusesIt() {
    RefusingClipboard.refuses = { it.getItemAt(0).htmlText != null }
    val (view, copies) = styledTextSelecting(6, 11)

    assertTrue(pressCtrlC(view))

    assertEquals(listOf(Copy("world", SelectionCopyFormat.PLAIN, 6, 11)), copies)
    assertEquals("world", clipboardText())
    assertNull(clipboardHtml())
  }

  @Test
  @Config(shadows = [RefusingClipboard::class])
  fun ctrlCReportsNothingWhenTheClipboardRefusesTheCopy() {
    RefusingClipboard.refuses = { true }
    val (view, copies) = segmentSelecting(7, 9)
    val toolbar = FakeActionMode()
    view.customSelectionActionModeCallback!!.onCreateActionMode(toolbar, MenuBuilder(context))

    assertTrue(pressCtrlC(view))

    assertEquals(emptyList<Copy>(), copies)
    assertFalse(toolbar.finished)
  }

  @Test
  @Config(shadows = [RefusingClipboard::class])
  fun menuItemsReportNothingWhenTheClipboardRefusesTheCopy() {
    RefusingClipboard.refuses = { true }
    val (view, copies) = segmentSelecting(7, 9)
    view.selectionMenuConfig = SelectionMenuConfig(copyAsMarkdownLabel = "Copy as Markdown")
    val toolbar = FakeActionMode()
    view.customSelectionActionModeCallback!!.onCreateActionMode(toolbar, MenuBuilder(context))

    clickMenuItem(view, "Copy", toolbar)
    clickMenuItem(view, "Copy as Markdown", toolbar)

    assertEquals(emptyList<Copy>(), copies)
    assertFalse(toolbar.finished)
  }
}

/** Throws on the clips [refuses] matches, the way the clipboard service does on one over the binder limit. */
@Implements(ClipboardManager::class)
class RefusingClipboard : ShadowClipboardManager() {
  @Implementation
  override fun setPrimaryClip(clip: ClipData) {
    if (refuses(clip)) throw RuntimeException(TransactionTooLargeException())
    super.setPrimaryClip(clip)
  }

  companion object {
    var refuses: (ClipData) -> Boolean = { false }
  }
}

private class FakeActionMode : ActionMode() {
  var finished = false

  override fun finish() {
    finished = true
  }

  override fun setTitle(title: CharSequence?) {}

  override fun setTitle(resId: Int) {}

  override fun setSubtitle(subtitle: CharSequence?) {}

  override fun setSubtitle(resId: Int) {}

  override fun setCustomView(view: View?) {}

  override fun invalidate() {}

  override fun getMenu(): Menu? = null

  override fun getTitle(): CharSequence? = null

  override fun getSubtitle(): CharSequence? = null

  override fun getCustomView(): View? = null

  override fun getMenuInflater(): MenuInflater? = null
}
