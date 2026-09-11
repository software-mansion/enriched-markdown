package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.TextView
import androidx.core.view.ViewCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.TestAstFactory.table
import com.swmansion.enriched.markdown.test.TestAstFactory.tableBody
import com.swmansion.enriched.markdown.test.TestAstFactory.tableCell
import com.swmansion.enriched.markdown.test.TestAstFactory.tableHead
import com.swmansion.enriched.markdown.test.TestAstFactory.tableHeaderCell
import com.swmansion.enriched.markdown.test.TestAstFactory.tableRow
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class TableContainerViewTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private fun newTableView(): TableContainerView = TableContainerView(context, defaultStyle)

  private fun gridOf(view: TableContainerView): ViewGroup = (view.getChildAt(0) as HorizontalScrollView).getChildAt(0) as ViewGroup

  private fun gridChildren(view: TableContainerView): List<View> {
    val grid = gridOf(view)
    return (0 until grid.childCount).map { grid.getChildAt(it) }
  }

  /** Row overlays are plain [View]s; every cell background is a [ViewGroup] holding one [TextView]. */
  private fun overlaysOf(view: TableContainerView): List<View> = gridChildren(view).filter { it !is ViewGroup }

  private fun cellBackgroundsOf(view: TableContainerView): List<ViewGroup> = gridChildren(view).filterIsInstance<ViewGroup>()

  /** TextView.setGravity ORs in a vertical bit of its own, so only the horizontal half is comparable. */
  private fun horizontalGravityOf(view: TextView): Int = view.gravity and Gravity.RELATIVE_HORIZONTAL_GRAVITY_MASK

  private fun textViewWithText(
    view: TableContainerView,
    expected: String,
  ): TextView =
    cellBackgroundsOf(view)
      .mapNotNull { it.getChildAt(0) as? TextView }
      .first { it.text.toString() == expected }

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

  private val threeByThreeTable =
    table(
      head =
        tableHead(
          tableRow(
            tableHeaderCell("default", text("H1")),
            tableHeaderCell("default", text("H2")),
            tableHeaderCell("default", text("H3")),
          ),
        ),
      body =
        tableBody(
          tableRow(tableCell("default", text("R1C1")), tableCell("default", text("R1C2")), tableCell("default", text("R1C3"))),
          tableRow(tableCell("default", text("R2C1")), tableCell("default", text("R2C2")), tableCell("default", text("R2C3"))),
        ),
    )

  @Test
  fun gridHoldsOneOverlayPerRowAndOneCellPerCell() {
    val view = newTableView().apply { applyTableNode(threeByThreeTable) }
    layOut(view, CONTAINER_WIDTH)

    val overlays = overlaysOf(view)
    val cells = cellBackgroundsOf(view)

    assertEquals(3, overlays.size)
    assertEquals(9, cells.size)

    val byRowNumber = overlays.sortedBy { rowNumberOf(it) }
    assertEquals(listOf(1, 2, 3), byRowNumber.map { rowNumberOf(it) })

    val expectedRowTexts = listOf(listOf("H1", "H2", "H3"), listOf("R1C1", "R1C2", "R1C3"), listOf("R2C1", "R2C2", "R2C3"))
    byRowNumber.forEachIndexed { index, overlay ->
      val description = overlay.contentDescription.toString()
      assertNotNull(overlay.contentDescription)
      assertTrue(description.startsWith("Row "))
      expectedRowTexts[index].forEach { cellText -> assertTrue(description.contains(cellText)) }
    }
  }

  private fun rowNumberOf(overlay: View): Int =
    requireNotNull(Regex("""Row (\d+):""").find(overlay.contentDescription.toString())).groupValues[1].toInt()

  @Test
  fun headerRowOverlayIsAnAccessibilityHeadingAndBodyRowsAreNot() {
    val view = newTableView().apply { applyTableNode(threeByThreeTable) }
    layOut(view, CONTAINER_WIDTH)

    val overlays = overlaysOf(view).sortedBy { rowNumberOf(it) }

    assertTrue(ViewCompat.isAccessibilityHeading(overlays[0]))
    assertFalse(ViewCompat.isAccessibilityHeading(overlays[1]))
    assertFalse(ViewCompat.isAccessibilityHeading(overlays[2]))
  }

  @Test
  fun cellTextUsesHeaderOrBodyColorAndCarriesTheExpectedString() {
    val view = newTableView().apply { applyTableNode(threeByThreeTable) }
    layOut(view, CONTAINER_WIDTH)

    val headerCell = textViewWithText(view, "H2")
    val bodyCell = textViewWithText(view, "R1C2")

    assertEquals("H2", headerCell.text.toString())
    assertEquals(defaultStyle.tableStyle.headerTextColor, headerCell.currentTextColor)

    assertEquals("R1C2", bodyCell.text.toString())
    assertEquals(defaultStyle.tableStyle.color, bodyCell.currentTextColor)
  }

  @Test
  fun cellAlignmentReachesTheTextViewGravity() {
    val node =
      table(
        body =
          tableBody(
            tableRow(
              tableCell("center", text("Centered")),
              tableCell("right", text("Righted")),
              tableCell("default", text("Started")),
            ),
          ),
      )
    val view = newTableView().apply { applyTableNode(node) }
    layOut(view, CONTAINER_WIDTH)

    assertEquals(Gravity.CENTER_HORIZONTAL, horizontalGravityOf(textViewWithText(view, "Centered")))
    assertEquals(Gravity.END, horizontalGravityOf(textViewWithText(view, "Righted")))
    assertEquals(Gravity.START, horizontalGravityOf(textViewWithText(view, "Started")))
  }

  @Test
  fun columnWidthGrowsWithItsLongestCellContent() {
    val longText = "This is a substantially longer piece of cell content than its neighbour"
    val shortText = "Hi"
    val node = table(body = tableBody(tableRow(tableCell("default", text(longText)), tableCell("default", text(shortText)))))

    val view = newTableView().apply { applyTableNode(node) }

    val cells = cellBackgroundsOf(view)
    assertEquals(2, cells.size)
    val firstColumnWidth = (cells[0].layoutParams as FrameLayout.LayoutParams).width
    val secondColumnWidth = (cells[1].layoutParams as FrameLayout.LayoutParams).width

    assertTrue("expected first column ($firstColumnWidth) wider than second ($secondColumnWidth)", firstColumnWidth > secondColumnWidth)
  }

  @Test
  fun wideTableScrollsWhileNarrowTableDoesNot() {
    val longCell = "A very long line of cell text that forces this column wide"
    val wideTable =
      table(
        body =
          tableBody(
            tableRow(
              tableCell("default", text(longCell)),
              tableCell("default", text(longCell)),
              tableCell("default", text(longCell)),
              tableCell("default", text(longCell)),
              tableCell("default", text(longCell)),
            ),
          ),
      )
    val narrowTable = table(body = tableBody(tableRow(tableCell("default", text("A")), tableCell("default", text("B")))))

    val wideView = newTableView().apply { applyTableNode(wideTable) }
    val narrowView = newTableView().apply { applyTableNode(narrowTable) }

    layOut(wideView, SCROLL_TEST_WIDTH)
    layOut(narrowView, SCROLL_TEST_WIDTH)

    val wideScrollView = wideView.getChildAt(0) as HorizontalScrollView
    val narrowScrollView = narrowView.getChildAt(0) as HorizontalScrollView

    assertTrue(wideScrollView.isHorizontalScrollBarEnabled)
    assertFalse(narrowScrollView.isHorizontalScrollBarEnabled)
  }

  private companion object {
    const val CONTAINER_WIDTH = 720
    const val SCROLL_TEST_WIDTH = 400
  }
}
