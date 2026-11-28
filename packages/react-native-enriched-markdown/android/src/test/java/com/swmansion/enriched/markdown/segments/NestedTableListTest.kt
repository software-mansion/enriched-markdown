package com.swmansion.enriched.markdown.segments

import android.text.Spannable
import android.text.Spanned
import android.text.style.StrikethroughSpan
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.widget.TextView
import com.swmansion.enriched.markdown.EnrichedMarkdownInternalText
import com.swmansion.enriched.markdown.accessibility.AccessibilityLabels
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.parser.MarkdownASTNode.NodeType
import com.swmansion.enriched.markdown.spans.BaseListSpan
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayMode
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.MarkerCanvas
import com.swmansion.enriched.markdown.test.TestAstFactory.listItem
import com.swmansion.enriched.markdown.test.TestAstFactory.orderedList
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.taskListItem
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import com.swmansion.enriched.markdown.test.TestAstFactory.unorderedList
import com.swmansion.enriched.markdown.utils.common.layout.isLayoutRTL
import com.swmansion.enriched.markdown.utils.text.conversion.HTMLGenerator
import com.swmansion.enriched.markdown.utils.text.conversion.MarkdownExtractor
import com.swmansion.enriched.markdown.utils.text.view.SelectionMenuConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class NestedTableListTest {
  @Test
  fun aListContainingATableKeepsABlockRenderingPath() {
    val table = MarkdownASTNode(NodeType.Table)
    val list = unorderedList(listItem(paragraph(text("Deployment")), table, paragraph(text("After"))))
    val document = MarkdownASTNode(NodeType.Document, children = listOf(list))
    val segment = splitASTIntoSegments(document).single()
    assertFalse("A text segment cannot create a native table view for the nested table", segment is MarkdownSegment.Text)
  }

  @Test
  fun existingAndNewNestedLeavesHonorLiveHostConfiguration() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    var overlay = SpoilerOverlayMode.SOLID
    val config =
      config(style).copy(configureView = { view ->
        if (view is EnrichedMarkdownInternalText) view.spoilerOverlay = overlay
      })
    val view = ListContainerView(context, config)
    val initial = unorderedList(listItem(paragraph(text("Before")), table()))
    view.applyList(RenderedSegment.ListBlock(initial, 1L))
    val first = view.descendantSegmentViews().filterIsInstance<EnrichedMarkdownInternalText>().single()
    assertEquals(SpoilerOverlayMode.SOLID, first.spoilerOverlay)
    overlay = SpoilerOverlayMode.PARTICLES
    view.descendantSegmentViews().filterIsInstance<EnrichedMarkdownInternalText>().forEach { it.spoilerOverlay = overlay }
    val appended = unorderedList(listItem(paragraph(text("Before")), table(), paragraph(text("After"))))
    view.applyList(RenderedSegment.ListBlock(appended, 2L))
    val leaves = view.descendantSegmentViews().filterIsInstance<EnrichedMarkdownInternalText>().toList()
    assertEquals(2, leaves.size)
    assertSame(first, leaves.first())
    assertTrue(leaves.all { it.spoilerOverlay == SpoilerOverlayMode.PARTICLES })
  }

  @Test
  fun ordinaryListsKeepTheirTextRenderingPath() {
    val list = unorderedList(listItem(paragraph(text("Deployment"))))
    val document = MarkdownASTNode(NodeType.Document, children = listOf(list))
    assertTrue(splitASTIntoSegments(document).single() is MarkdownSegment.Text)
  }

  @Test
  fun nestedTablesRemainNativeViewsWithContinuationTextAndMatchingHeight() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val config =
      config(style)
    val table = table()
    for (shape in 0..5) {
      val block =
        when (shape) {
          2 -> unorderedList(listItem(table))
          3 -> MarkdownASTNode(NodeType.Blockquote, children = listOf(table))
          else -> table
        }
      val item =
        if (shape == 4) {
          listItem(block, paragraph(text("Before")), paragraph(text("After")))
        } else {
          listItem(paragraph(text("Before")), block, paragraph(text("After")))
        }
      val sibling = listItem(paragraph(text("Next item")))
      val list = if (shape % 2 == 1) orderedList(item, sibling, start = 999) else unorderedList(item, sibling)
      val document = MarkdownASTNode(NodeType.Document, children = listOf(list))
      val segment =
        MarkdownSegmentRenderer
          .render(
            splitASTIntoSegments(document),
            style,
            context,
            null,
            null,
          ).single() as RenderedSegment.ListBlock
      val view = ListContainerView(context, config).apply { applyList(segment) }
      view.measure(
        View.MeasureSpec.makeMeasureSpec(360, View.MeasureSpec.EXACTLY),
        View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
      )
      view.layout(0, 0, 360, view.measuredHeight)
      val nativeTable = descendants(view).filterIsInstance<TableContainerView>().single()
      assertEquals(2, nativeTable.rowCount)
      val strings = descendants(view).filterIsInstance<TextView>().map { it.text.toString() }.toList()
      for (content in listOf("Before", "After", "Service", "api", "Next item")) {
        assertTrue("Missing $content in $strings", strings.any { it.contains(content) })
      }
      val measured =
        ListContainerView.measureListHeight(
          segment,
          style,
          context,
          360f,
          null,
          null,
          0f,
          0f,
          android.text.Layout.BREAK_STRATEGY_HIGH_QUALITY,
        )
      assertEquals(view.measuredHeight.toFloat(), measured, 1f)
      view.applyList(segment)
      assertSame(nativeTable, descendants(view).filterIsInstance<TableContainerView>().single())
    }
  }

  @Test
  fun taskMarkersKeepTheirGlobalIndexAndAccessibilityState() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val clicks = mutableListOf<Pair<Int, Boolean>>()
    val dynamicProps = DynamicBlockProps()
    val config =
      config(style, dynamicProps) { index, checked, _ -> clicks.add(index to checked) }
    val node = unorderedList(taskListItem(false, paragraph(text("Deploy")), table()), taskListItem(true, paragraph(text("Check"))))
    val segment = RenderedSegment.ListBlock(node, 1L, taskIndexOffset = 4)
    val view = ListContainerView(context, config).apply { applyList(segment) }
    val checkboxes = descendants(view).filter { it.visibility == View.VISIBLE && it.createAccessibilityNodeInfo().isCheckable }.toList()
    assertEquals(2, checkboxes.size)
    assertFalse(checkboxes[0].createAccessibilityNodeInfo().isChecked)
    assertTrue(checkboxes[1].createAccessibilityNodeInfo().isChecked)
    checkboxes[0].performClick()
    checkboxes[1].performClick()
    assertEquals(listOf(4 to false, 5 to true), clicks)
    dynamicProps.enableTaskListItemToggle = false
    checkboxes[0].performClick()
    assertEquals(2, clicks.size)
    val accessible = ArrayList<View>().also { view.addChildrenForAccessibility(it) }
    assertTrue(accessible.containsAll(checkboxes))
  }

  @Test
  fun togglingACheckedItemUpdatesExistingBodyStyling() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig(taskList = mapOf("checkedTextColor" to android.graphics.Color.RED, "checkedStrikethrough" to true))
    val config = config(style)

    fun segment(checked: Boolean): RenderedSegment.ListBlock =
      RenderedSegment.ListBlock(
        unorderedList(taskListItem(checked, paragraph(text("Deploy")), table())),
        1L,
      )
    val view = ListContainerView(context, config).apply { applyList(segment(false)) }

    fun body() = descendants(view).filterIsInstance<TextView>().first { it.text.toString().startsWith("Deploy") }
    val original = body()
    for (checked in listOf(true, false)) {
      view.applyList(segment(checked))
      assertSame(original, body())
      val spans = (body().text as Spanned).getSpans(0, body().text.length, StrikethroughSpan::class.java)
      assertEquals(checked, spans.isNotEmpty())
    }
  }

  @Test
  fun nestedMarkersKeepTheirGapBesideTheBody() = assertMarkerGaps()

  @Test
  @Config(sdk = [30], qualifiers = "ldrtl")
  fun rightToLeftNestedMarkersKeepTheirGapBesideTheBody() = assertMarkerGaps(arabic = true)

  @Test
  fun arabicItemsUseRightToLeftMarkersInAnEnglishInterface() = assertMarkerGaps(arabic = true)

  private fun assertMarkerGaps(arabic: Boolean = false) {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val childLabel = if (arabic) "طفل" else "Child"
    val parentLabel = if (arabic) "أصل" else "Parent"
    val nested = unorderedList(listItem(paragraph(text(childLabel)), table()))
    val root = orderedList(listItem(paragraph(text(parentLabel)), nested), start = 999)
    val document = MarkdownASTNode(NodeType.Document, children = listOf(root))
    val segment =
      MarkdownSegmentRenderer
        .render(
          splitASTIntoSegments(document),
          style,
          context,
          null,
          null,
        ).single() as RenderedSegment.ListBlock
    val view = ListContainerView(context, config(style)).apply { applyList(segment) }
    view.measure(
      View.MeasureSpec.makeMeasureSpec(360, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, 360, view.measuredHeight)
    for (list in descendants(view).filterIsInstance<ListContainerView>()) {
      val item = list.getChildAt(0)
      val canvas = MarkerCanvas()
      item.draw(canvas)
      val marker = canvas.markers.first()
      val gap =
        if (arabic) {
          (
            if (list ===
              view
            ) {
              marker.left
            } else {
              marker.right
            }
          ) - (item.width - item.paddingRight)
        } else {
          item.paddingLeft - marker.right
        }
      assertEquals(style.listStyle.gapWidth.coerceAtLeast(4f), gap, 1f)
    }
    val childText = descendants(view).filterIsInstance<EnrichedMarkdownInternalText>().first { it.text.toString().startsWith(childLabel) }
    val labels = AccessibilityLabels(nestedBulletPoint = "nested bullet")
    childText.accessibilityLabels = labels
    val provider = childText.accessibilityHelper.getAccessibilityNodeProvider(childText)!!
    val node = provider.createAccessibilityNodeInfo(0)!!
    assertEquals("nested bullet", node.roleDescription.toString())
  }

  @Test
  fun aTableFirstTaskCanBeTappedAtItsDrawnCheckbox() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig(table = mapOf("marginTop" to 40.0, "cellPaddingVertical" to 20.0))
    var pressed = false
    val node = unorderedList(taskListItem(false, table()))
    val config = config(style, onTask = { _, _, _ -> pressed = true })
    val view = ListContainerView(context, config).apply { applyList(RenderedSegment.ListBlock(node, 1L)) }
    val controller =
      org.robolectric.Robolectric
        .buildActivity(android.app.Activity::class.java)
        .setup()
    val root =
      object : android.widget.FrameLayout(context), com.facebook.react.uimanager.RootView {
        override fun onChildStartedNativeGesture(
          childView: View?,
          event: MotionEvent,
        ) = Unit

        override fun onChildEndedNativeGesture(
          childView: View,
          event: MotionEvent,
        ) = Unit

        override fun handleException(t: Throwable): Unit = throw t
      }
    root.addView(view)
    controller.get().setContentView(root)
    org.robolectric.Shadows
      .shadowOf(android.os.Looper.getMainLooper())
      .idle()
    view.measure(
      View.MeasureSpec.makeMeasureSpec(360, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, 360, view.measuredHeight)
    val canvas = MarkerCanvas()
    view.getChildAt(0).draw(canvas)
    val checkbox = canvas.markers.first()
    val x = (checkbox.left + checkbox.right) / 2f
    val y = checkbox.baseline
    val down = MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, x, y, 0)
    val up = MotionEvent.obtain(0, 1, MotionEvent.ACTION_UP, x, y, 0)
    try {
      val checkboxView = descendants(view).first { it.visibility == View.VISIBLE && it.createAccessibilityNodeInfo().isCheckable }
      val bounds = android.graphics.Rect().also { checkboxView.getHitRect(it) }
      assertTrue("point $x,$y outside $bounds", bounds.contains(x.toInt(), y.toInt()))
      val consumed = view.dispatchTouchEvent(down)
      view.dispatchTouchEvent(up)
      org.robolectric.Shadows
        .shadowOf(android.os.Looper.getMainLooper())
        .idle()
      assertTrue("touch consumed=$consumed, bounds=$bounds, point=$x,$y", pressed)
    } finally {
      down.recycle()
      up.recycle()
      controller.pause().stop().destroy()
    }
  }

  @Test
  fun listContextSurvivesAQuoteContainingAPlainNestedList() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val child = unorderedList(listItem(paragraph(text("Nested child"))))
    val quote = MarkdownASTNode(NodeType.Blockquote, children = listOf(child))
    val node = orderedList(listItem(paragraph(text("Parent")), table(), quote), start = 999)
    val view = ListContainerView(context, config(style)).apply { applyList(RenderedSegment.ListBlock(node, 1L)) }
    val text = descendants(view).filterIsInstance<TextView>().first { it.text.toString().contains("Nested child") }.text as Spanned
    val info =
      text
        .getSpans(
          0,
          text.length,
          com.swmansion.enriched.markdown.accessibility.MarkdownAccessibilityHelper.ListItemInfo::class.java,
        ).single()
    assertEquals(1, info.depth)
  }

  @Test
  fun nativeListBodiesKeepTheirClipboardMarkupWithoutVisualListSpans() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val node = orderedList(listItem(paragraph(text("Before")), table(), paragraph(text("After"))), start = 7)
    val view = ListContainerView(context, config(style)).apply { applyList(RenderedSegment.ListBlock(node, 1L)) }
    val bodies =
      descendants(view).filterIsInstance<TextView>().filter {
        it.text.toString().startsWith("Before") ||
          it.text.toString().startsWith("After")
      }
    for (body in bodies) {
      val text = body.text as Spannable
      assertEquals(0, text.getSpans(0, text.length, BaseListSpan::class.java).size)
      assertTrue(MarkdownExtractor.extractFromSpannable(text, 0, text.length).startsWith("7. "))
      val html = HTMLGenerator.generateHTML(text, style)
      assertTrue(html.contains("<ol"))
      assertTrue(html.contains("<li"))
    }
  }

  @Test
  fun switchingListTypeRefreshesClipboardMetadata() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val item = listItem(paragraph(text("Before")), table())
    val view = ListContainerView(context, config(style))
    view.applyList(RenderedSegment.ListBlock(unorderedList(item), 1L))
    val before = view.descendantSegmentViews().filterIsInstance<EnrichedMarkdownInternalText>().single()
    view.applyList(RenderedSegment.ListBlock(orderedList(item, start = 1), 2L))
    val after = view.descendantSegmentViews().filterIsInstance<EnrichedMarkdownInternalText>().single()
    assertSame(before, after)
    val text = after.text as Spannable
    assertTrue(MarkdownExtractor.extractFromSpannable(text, 0, text.length).startsWith("1. "))
  }

  private fun config(
    style: StyleConfig,
    dynamicProps: DynamicBlockProps = DynamicBlockProps(),
    onTask: ((Int, Boolean, String) -> Unit)? = null,
  ): SegmentViewConfig =
    SegmentViewConfig(
      context = RuntimeEnvironment.getApplication(),
      style = style,
      allowFontScaling = false,
      maxFontSizeMultiplier = 0f,
      accessibilityLabels = AccessibilityLabels(),
      selectionMenuConfig = SelectionMenuConfig(),
      textBreakStrategy = "highQuality",
      selectable = false,
      selectionColor = null,
      selectionHandleColor = null,
      contextMenuItemTexts = emptyList(),
      dynamicProps = dynamicProps,
      onLinkPress = null,
      onLinkLongPress = null,
      onTaskListItemPress = onTask,
      onContextMenuItemPress = null,
    )

  private fun descendants(view: View): Sequence<View> =
    sequence {
      yield(view)
      if (view is ViewGroup) for (index in 0 until view.childCount) yieldAll(descendants(view.getChildAt(index)))
    }

  private fun table(): MarkdownASTNode =
    MarkdownASTNode(
      NodeType.Table,
      children =
        listOf(
          MarkdownASTNode(
            NodeType.TableHead,
            children =
              listOf(
                MarkdownASTNode(
                  NodeType.TableRow,
                  children = listOf(MarkdownASTNode(NodeType.TableHeaderCell, children = listOf(text("Service")))),
                ),
              ),
          ),
          MarkdownASTNode(
            NodeType.TableBody,
            children =
              listOf(
                MarkdownASTNode(NodeType.TableRow, children = listOf(MarkdownASTNode(NodeType.TableCell, children = listOf(text("api"))))),
              ),
          ),
        ),
    )
}
