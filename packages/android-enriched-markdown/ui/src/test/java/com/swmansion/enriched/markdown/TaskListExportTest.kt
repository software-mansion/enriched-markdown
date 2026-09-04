package com.swmansion.enriched.markdown

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.HTMLAssertions.assertContainsHtml
import com.swmansion.enriched.markdown.test.HTMLGeneratorTestSupport.generateHTML
import com.swmansion.enriched.markdown.test.MarkdownExtractorTestSupport.extractSelectingText
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

/** Task-list behaviour on the export path: spans -> HTML and spans -> Markdown. */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class TaskListExportTest {
  @Test
  fun plainItemsOfAMixedListKeepTheirBulletInHtml() {
    val html =
      generateHTML(
        render(
          document(
            unorderedList(
              taskListItem(checked = true, paragraph(text("Done item"))),
              taskListItem(checked = false, paragraph(text("Open item"))),
              listItem(paragraph(text("Plain item"))),
            ),
          ),
        ),
      )

    // The `<ul>` must reopen as `disc` once the plain item follows the task items.
    html.assertContainsHtml("list-style-type: disc")
  }

  @Test
  fun taskItemsOfAMixedListHaveNoBulletInHtml() {
    val html =
      generateHTML(
        render(
          document(
            unorderedList(
              listItem(paragraph(text("Plain item"))),
              taskListItem(checked = true, paragraph(text("Done item"))),
            ),
          ),
        ),
      )

    html.assertContainsHtml("list-style-type: none")
  }

  @Test
  fun plainChildOfACheckedTaskIsNotACheckboxInHtml() {
    val html =
      generateHTML(
        render(
          document(
            unorderedList(
              taskListItem(
                checked = true,
                paragraph(text("Parent task")),
                unorderedList(listItem(paragraph(text("Plain nested")))),
              ),
            ),
          ),
        ),
      )

    assertEquals(
      "Only the parent task is checked, so exactly one checkmark is expected: $html",
      1,
      html.occurrencesOf(CHECKMARK),
    )
  }

  @Test
  fun plainChildOfACheckedTaskKeepsItsNestingInHtml() {
    val html =
      generateHTML(
        render(
          document(
            unorderedList(
              taskListItem(
                checked = true,
                paragraph(text("Parent task")),
                unorderedList(listItem(paragraph(text("Plain nested")))),
              ),
            ),
          ),
        ),
      )

    assertEquals(
      "Expected an outer and an inner <ul>: $html",
      2,
      html.occurrencesOf("<ul"),
    )
  }

  @Test
  fun extractsPlainChildOfACheckedTaskAsAPlainBullet() {
    val checklist =
      document(
        unorderedList(
          taskListItem(
            checked = true,
            paragraph(text("Parent task")),
            unorderedList(listItem(paragraph(text("Plain nested")))),
          ),
        ),
      )

    assertEquals("  - Plain nested", extractSelectingText(checklist, "Plain nested"))
  }

  @Test
  fun extractsPlainChildOfAnOrderedItemAsAPlainBullet() {
    val list =
      document(
        orderedList(
          listItem(paragraph(text("First item"))),
          listItem(
            paragraph(text("Second item")),
            unorderedList(listItem(paragraph(text("Plain nested")))),
          ),
        ),
      )

    assertEquals("  - Plain nested", extractSelectingText(list, "Plain nested"))
  }

  private fun String.occurrencesOf(part: String): Int {
    var count = 0
    var index = indexOf(part)

    while (index >= 0) {
      count++
      index = indexOf(part, index + part.length)
    }

    return count
  }

  private companion object {
    const val CHECKMARK = "&#10003;"
  }
}
