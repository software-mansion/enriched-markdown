package com.swmansion.enriched.markdown

import android.content.Context
import android.view.View
import android.view.ViewGroup
import androidx.core.view.ViewCompat
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.segments.TableContainerView
import com.swmansion.enriched.markdown.styles.StyleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [26, 27, 28])
class TableAccessibilityTest {
  @Test
  fun rendersAccessibleHeaderAndBodyRows() {
    val context = ApplicationProvider.getApplicationContext<Context>()
    val table = TableContainerView(context, StyleConfig.default(context))
    val tableNode =
      MarkdownASTNode(
        NodeType.Table,
        children =
          listOf(
            section(NodeType.TableHead, NodeType.TableHeaderCell, "Name", "Value"),
            section(NodeType.TableBody, NodeType.TableCell, "Example", "42"),
          ),
      )

    // Re-applying also covers replacement of the overlays during streaming updates.
    repeat(2) {
      table.applyTableNode(tableNode)

      val scrollView = table.getChildAt(0) as ViewGroup
      val grid = scrollView.getChildAt(0) as ViewGroup
      val overlays =
        (0 until grid.childCount)
          .map { grid.getChildAt(it) }
          .filter { it.contentDescription != null }

      assertEquals(listOf("Row 1: Name, Value", "Row 2: Example, 42"), overlays.map { it.contentDescription.toString() })
      overlays.forEach {
        assertTrue(it.isFocusable)
        assertTrue(ViewCompat.isScreenReaderFocusable(it))
        assertEquals(View.IMPORTANT_FOR_ACCESSIBILITY_YES, it.importantForAccessibility)
      }
      assertTrue(ViewCompat.isAccessibilityHeading(overlays[0]))
      assertFalse(ViewCompat.isAccessibilityHeading(overlays[1]))
    }
  }

  private fun section(
    sectionType: NodeType,
    cellType: NodeType,
    vararg values: String,
  ): MarkdownASTNode =
    MarkdownASTNode(
      sectionType,
      children =
        listOf(
          MarkdownASTNode(
            NodeType.TableRow,
            children = values.map { MarkdownASTNode(cellType, children = listOf(MarkdownASTNode(NodeType.Text, content = it))) },
          ),
        ),
    )
}
