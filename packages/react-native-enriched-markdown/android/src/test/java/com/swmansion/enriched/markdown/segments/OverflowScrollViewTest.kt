package com.swmansion.enriched.markdown.segments

import android.view.View
import android.view.View.MeasureSpec
import android.widget.FrameLayout
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class OverflowScrollViewTest {
  private val context = RuntimeEnvironment.getApplication()

  private fun scrollViewWithContent(contentWidth: Int): Pair<OverflowScrollView, View> {
    // HorizontalScrollView measures its child unconstrained, so the content reports its width as a minimum.
    val content = View(context).apply { minimumWidth = contentWidth }
    val scrollView = OverflowScrollView(context)
    scrollView.addView(content, FrameLayout.LayoutParams(FrameLayout.LayoutParams.WRAP_CONTENT, 50))
    return scrollView to content
  }

  private fun layOut(
    view: View,
    width: Int,
  ) {
    view.measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
    view.layout(0, 0, width, view.measuredHeight)
  }

  // Attached with the scrollbar off, so it has nothing to fade in and out.
  @Test
  fun startsWithoutAScrollbar() {
    assertFalse(scrollViewWithContent(500).first.isHorizontalScrollBarEnabled)
  }

  @Test
  fun enablesTheScrollbarOnlyWhileTheContentOverflows() {
    val (scrollView, content) = scrollViewWithContent(500)
    layOut(scrollView, 200)
    assertTrue(scrollView.isHorizontalScrollBarEnabled)

    content.minimumWidth = 150
    layOut(scrollView, 200)
    assertFalse(scrollView.isHorizontalScrollBarEnabled)
  }
}
