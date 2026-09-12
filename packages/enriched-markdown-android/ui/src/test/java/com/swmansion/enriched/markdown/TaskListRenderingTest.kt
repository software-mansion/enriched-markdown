package com.swmansion.enriched.markdown

import android.text.SpannableString
import android.text.style.ForegroundColorSpan
import android.text.style.StrikethroughSpan
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.spans.CodeBlockSpan
import com.swmansion.enriched.markdown.spans.TaskListSpan
import com.swmansion.enriched.markdown.spans.UnorderedListSpan
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtml
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtmlInOrder
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTMLSelectingText
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport.extractSelectingText
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultTaskListStyle
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleWithTaskList
import com.swmansion.enriched.markdown.test.TestAstFactory.codeBlock
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class TaskListRenderingTest {
  @Test
  fun rendersTaskItemsWithTheirCheckedState() {
    val rendered =
      render(
        document(
          unorderedList(
            taskListItem(checked = true, paragraph(text("Done item"))),
            taskListItem(checked = false, paragraph(text("Open item"))),
          ),
        ),
      )

    assertEquals(true, rendered.taskSpanCovering("Done item").isChecked)
    assertEquals(false, rendered.taskSpanCovering("Open item").isChecked)
  }

  @Test
  fun leavesPlainItemsOfAMixedListAsBullets() {
    val rendered =
      render(
        document(
          unorderedList(
            taskListItem(checked = false, paragraph(text("Task item"))),
            listItem(paragraph(text("Plain item"))),
          ),
        ),
      )

    val plainRange = rendered.rangeOf("Plain item")
    assertTrue(
      "Expected a plain bullet on the non-task item",
      rendered.getSpans(plainRange.first, plainRange.last, UnorderedListSpan::class.java).isNotEmpty(),
    )
    assertTrue(
      "Did not expect a checkbox on the non-task item",
      rendered.getSpans(plainRange.first, plainRange.last, TaskListSpan::class.java).isEmpty(),
    )
  }

  @Test
  fun nestedTaskItemsKeepTheirOwnDepth() {
    val rendered =
      render(
        document(
          unorderedList(
            taskListItem(
              checked = true,
              paragraph(text("Parent task")),
              unorderedList(taskListItem(checked = false, paragraph(text("Nested task")))),
            ),
          ),
        ),
      )

    assertEquals(0, rendered.taskSpanCovering("Parent task").depth)
    assertEquals(1, rendered.taskSpanCovering("Nested task").depth)
  }

  @Test
  fun checkedItemsAreNotDecoratedByDefault() {
    val rendered =
      render(
        document(unorderedList(taskListItem(checked = true, paragraph(text("Done item"))))),
      )

    assertTrue(rendered.getSpans(0, rendered.length, StrikethroughSpan::class.java).isEmpty())
    assertTrue(rendered.getSpans(0, rendered.length, ForegroundColorSpan::class.java).isEmpty())
  }

  @Test
  fun checkedItemsAreStruckThroughAndRecoloredWhenConfigured() {
    val style =
      styleWithTaskList(
        defaultTaskListStyle().copy(
          checkedTextColor = CHECKED_TEXT_COLOR,
          checkedStrikethrough = true,
        ),
      )

    val rendered =
      render(
        document(
          unorderedList(
            taskListItem(checked = true, paragraph(text("Done item"))),
            taskListItem(checked = false, paragraph(text("Open item"))),
          ),
        ),
        style,
      )

    val done = rendered.rangeOf("Done item")
    assertTrue(rendered.getSpans(done.first, done.last, StrikethroughSpan::class.java).isNotEmpty())
    assertEquals(
      CHECKED_TEXT_COLOR,
      rendered
        .getSpans(done.first, done.last, ForegroundColorSpan::class.java)
        .first()
        .foregroundColor,
    )

    val open = rendered.rangeOf("Open item")
    assertTrue(rendered.getSpans(open.first, open.last, StrikethroughSpan::class.java).isEmpty())
    assertTrue(rendered.getSpans(open.first, open.last, ForegroundColorSpan::class.java).isEmpty())
  }

  @Test
  fun checkedDecorationSkipsNestedItemsAndCodeBlocks() {
    val style =
      styleWithTaskList(
        defaultTaskListStyle().copy(
          checkedTextColor = CHECKED_TEXT_COLOR,
          checkedStrikethrough = true,
        ),
      )

    val rendered =
      render(
        document(
          unorderedList(
            taskListItem(
              checked = true,
              paragraph(text("Parent task")),
              codeBlock("val answer = 42\n"),
              unorderedList(taskListItem(checked = false, paragraph(text("Nested task")))),
            ),
          ),
        ),
        style,
      )

    val nested = rendered.rangeOf("Nested task")
    assertTrue(
      "Nested items must not inherit the parent's strikethrough",
      rendered.getSpans(nested.first, nested.last, StrikethroughSpan::class.java).isEmpty(),
    )

    val codeSpan = rendered.getSpans(0, rendered.length, CodeBlockSpan::class.java).first()
    val codeStart = rendered.getSpanStart(codeSpan)
    val codeEnd = rendered.getSpanEnd(codeSpan)
    assertTrue(
      "Code blocks must not inherit the parent's strikethrough",
      rendered.getSpans(codeStart, codeEnd, StrikethroughSpan::class.java).isEmpty(),
    )

    val parent = rendered.rangeOf("Parent task")
    assertTrue(rendered.getSpans(parent.first, parent.last, StrikethroughSpan::class.java).isNotEmpty())
  }

  @Test
  fun generatesCheckedCheckboxHtml() {
    val html =
      generateHTMLSelectingText(
        document(unorderedList(taskListItem(checked = true, paragraph(text("Done item"))))),
        "Done item",
      )

    html.assertContainsHtml("list-style-type: none;")
    html.assertContainsHtmlInOrder("<ul", "<li", "<span", "&#10003;", "</span>", "Done item", "</li>", "</ul>")
  }

  @Test
  fun generatesUncheckedCheckboxHtml() {
    val html =
      generateHTMLSelectingText(
        document(unorderedList(taskListItem(checked = false, paragraph(text("Open item"))))),
        "Open item",
      )

    html.assertContainsHtml("list-style-type: none;")
    html.assertContainsHtml("border: 1.5px solid")
    assertFalse("Unchecked checkboxes must not draw a checkmark", html.contains("&#10003;"))
  }

  @Test
  fun extractsTaskItemsAsGfmCheckboxes() {
    val checklist =
      document(
        unorderedList(
          taskListItem(checked = true, paragraph(text("Done item"))),
          taskListItem(checked = false, paragraph(text("Open item"))),
        ),
      )

    assertEquals("- [x] Done item", extractSelectingText(checklist, "Done item"))
    assertEquals("- [ ] Open item", extractSelectingText(checklist, "Open item"))
  }

  @Test
  fun extractsNestedTaskItemsWithIndentation() {
    val checklist =
      document(
        unorderedList(
          taskListItem(
            checked = true,
            paragraph(text("Parent task")),
            unorderedList(taskListItem(checked = false, paragraph(text("Nested task")))),
          ),
        ),
      )

    assertEquals("  - [ ] Nested task", extractSelectingText(checklist, "Nested task"))
  }

  private fun SpannableString.rangeOf(text: String): IntRange {
    val start = indexOf(text)
    assertTrue("Rendered text does not contain \"$text\": \"$this\"", start >= 0)
    return start..(start + text.length)
  }

  private fun SpannableString.taskSpanCovering(text: String): TaskListSpan {
    val range = rangeOf(text)
    val spans = getSpans(range.first, range.last, TaskListSpan::class.java)
    assertTrue("Expected a TaskListSpan covering \"$text\"", spans.isNotEmpty())
    return spans.maxBy { it.depth }
  }

  private companion object {
    const val CHECKED_TEXT_COLOR = 0xFF9E9E9E.toInt()
  }
}
