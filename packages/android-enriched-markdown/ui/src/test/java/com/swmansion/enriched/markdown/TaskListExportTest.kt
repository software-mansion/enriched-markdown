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

/**
 * Regressions in the *export* path (spans -> HTML / spans -> Markdown) reported on PR #741.
 *
 * Two independent defects are covered:
 *  - [HTMLGenerator.handleList] picks a `<ul>`'s `list-style-type` from the first item at a depth
 *    and never reopens the list when task and plain items are mixed at that depth.
 *  - A list item's span covers its nested children (`ListItemRenderer` closes the span after
 *    `renderChildren`), so at a nested line every ancestor's span is returned too. Both
 *    `HTMLGenerator.collectParagraphs` and `MarkdownExtractor.detectList` read index `[0]` of that
 *    result instead of the span that actually starts on the line.
 */
@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
class TaskListExportTest {
  // --- HTMLGenerator: `<ul>` marker style is frozen when the list is opened -------------------

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

    // The list opens as `list-style-type: none` for the task items and is never reopened, so
    // `Plain item` renders without any marker at all.
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

    // Mirror case: the list opens as `disc`, so the task item draws a bullet *and* a checkbox.
    html.assertContainsHtml("list-style-type: none")
  }

  // --- HTMLGenerator: ancestor task spans leak onto nested lines ------------------------------

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

    // `getParagraphType` sees the parent's TaskListSpan on the nested line and types the plain
    // bullet as a checked task item, so a second checkmark is emitted.
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

    // `getDepthForType` only maxes over TaskListSpans for a task paragraph, so the nested plain
    // bullet reports the parent's depth (0) and is flattened into the outer list.
    assertEquals(
      "Expected an outer and an inner <ul>: $html",
      2,
      html.occurrencesOf("<ul"),
    )
  }

  // --- MarkdownExtractor: ancestor spans leak onto nested lines -------------------------------

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

    // `detectList` sees the parent's TaskListSpan and turns a plain bullet into a checked task,
    // so copying the document and pasting it back changes it.
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

    // Same defect on the ordered branch: `orderedSpans[0]` is the parent, so the nested bullet is
    // extracted as `2.`.
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
