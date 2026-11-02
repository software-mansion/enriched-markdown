package com.swmansion.enriched.markdown.utils.text.view

import android.content.ClipboardManager
import android.content.Context
import android.text.Selection
import android.text.Spannable
import android.view.KeyEvent
import android.view.Menu
import androidx.appcompat.view.menu.MenuBuilder
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.EnrichedMarkdownText
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

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

  // The system adds Copy; the callback adds the rest in onPrepareActionMode.
  private fun clickMenuItem(
    view: EnrichedMarkdownInternalText,
    title: String,
  ) {
    val menu = MenuBuilder(context)
    menu.add(Menu.NONE, android.R.id.copy, Menu.NONE, "Copy")
    val callback = view.customSelectionActionModeCallback!!
    callback.onPrepareActionMode(null, menu)
    val item = (0 until menu.size()).map(menu::getItem).first { it.title == title }
    assertTrue(callback.onActionItemClicked(null, item))
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
}
