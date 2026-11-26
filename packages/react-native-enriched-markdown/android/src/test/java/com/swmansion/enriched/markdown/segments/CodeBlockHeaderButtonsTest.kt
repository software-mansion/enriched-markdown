package com.swmansion.enriched.markdown.segments

import android.app.Activity
import android.content.Context
import android.graphics.Rect
import android.view.MotionEvent
import android.view.View
import android.view.View.MeasureSpec
import androidx.appcompat.widget.AppCompatImageButton
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLooper

// #1243: the code block's Copy and Wrap lines buttons were as tall and wide as the header, about
// 31 dp at the default text size. Each needs its own touch target of at least 48 dp.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30], qualifiers = "xxhdpi")
class CodeBlockHeaderButtonsTest {
  private val context: Context get() = RuntimeEnvironment.getApplication()
  private val density get() = context.resources.displayMetrics.density

  // Styles convert dp with React Native's metrics, a static that another test may have set for another
  // density; reset it afterwards so this one's doesn't leak either.
  @Before
  fun useThisDensity() {
    DisplayMetricsHolder.initDisplayMetrics(context)
  }

  @After
  fun resetDensity() {
    DisplayMetricsHolder.setScreenDisplayMetrics(null)
  }

  @Test
  fun eachHeaderButtonIsAtLeast48dpAndTheyDontOverlap() {
    val view = laidOutCodeBlock(showsWrapButton = true)
    val (copy, wrap) = headerButtons(view)

    for (button in listOf(copy, wrap)) {
      assertTrue("${button.width / density} dp wide", button.width >= 48 * density)
      assertTrue("${button.height / density} dp tall", button.height >= 48 * density)
      assertTrue("inside the block", button.left >= 0 && button.right <= view.width && button.top >= 0 && button.bottom <= view.height)
    }
    assertFalse(Rect.intersects(bounds(copy), bounds(wrap)))
  }

  @Test
  fun theCopyIconKeepsItsPlaceAndTheHeaderItsHeight() {
    val view = laidOutCodeBlock(showsWrapButton = false)
    val (copy, _) = headerButtons(view)
    val icon = copy.drawable.intrinsicWidth
    // ScaleType.CENTER centres the icon in the padded box.
    val iconRight = copy.left + copy.paddingLeft + (copy.width - copy.paddingLeft - copy.paddingRight + icon) / 2

    val inset = view.paddingForTest()
    assertEquals((view.width - inset).toFloat(), iconRight.toFloat(), 1f)
    // The shadow node sizes the block with the measurement's height, so the view must keep it.
    val measured = CodeBlockContainerView.measureCodeBlockNodeHeight(codeNode, style, context, WIDTH_PX.toFloat())
    assertEquals(measured, view.measuredHeight.toFloat(), 1f)
  }

  private val codeNode = MarkdownASTNode(MarkdownASTNode.NodeType.CodeBlock, children = listOf(text("const ready = true;\n")))

  // 14 sp text, as React Native's default. The padding is 24 dp rather than the default 16: Robolectric's
  // fonts give the header label almost no height, and the buttons stop at the first line of code, which
  // starts a header and a padding down (on a device the default style gives the full 48 dp).
  private val style get() = styleConfig(codeBlock = mapOf("fontSize" to 14.0, "padding" to 24.0))

  // Too narrow for two 48 dp targets, or for one: the buttons share the room and stay apart, inside the block.
  @Test
  fun aNarrowBlockKeepsItsButtonsApartAndInside() {
    for ((widthDp, showsWrap) in listOf(80 to true, 60 to true, 40 to false, 40 to true)) {
      val view =
        CodeBlockContainerView(context, style).apply {
          showsWrapButton = showsWrap
          applyCodeBlockNode(codeNode)
          val width = (widthDp * density).toInt()
          measure(MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
          layout(0, 0, measuredWidth, measuredHeight)
        }
      val (copy, wrap) = headerButtons(view)
      val shown = if (showsWrap) listOf(copy, wrap) else listOf(copy)
      for (button in shown) {
        assertTrue("$widthDp dp: inside the block", button.left >= 0 && button.right <= view.width)
        assertTrue("$widthDp dp: has a width", button.width > 0)
      }
      if (showsWrap) assertFalse("$widthDp dp: overlap", Rect.intersects(bounds(copy), bounds(wrap)))
    }
  }

  // A tap in the part of the target the old, header-sized button didn't cover reaches the button.
  @Test
  fun aTapBelowTheHeaderReachesTheWrapButton() {
    val view = laidOutCodeBlock(showsWrapButton = true)
    // Attached, so the click the button posts runs.
    Robolectric
      .buildActivity(Activity::class.java)
      .setup()
      .get()
      .setContentView(view)
    ShadowLooper.idleMainLooper()
    val (_, wrap) = headerButtons(view)
    var toggled = 0
    view.onWrapToggle = { toggled++ }
    // Three quarters of the way from the header to the first line of code: the old buttons, as tall
    // as the header, reached a quarter of the way.
    val header = headerHeightOf(view)
    val x = (wrap.left + wrap.right) / 2f
    val y = header + (firstLineTopOf(view) - header) * 0.75f

    view.dispatchTouchEvent(MotionEvent.obtain(0, 0, MotionEvent.ACTION_DOWN, x, y, 0))
    view.dispatchTouchEvent(MotionEvent.obtain(0, 10, MotionEvent.ACTION_UP, x, y, 0))
    ShadowLooper.idleMainLooper()

    assertEquals(1, toggled)
  }

  // With little padding the target stops where the first line of code starts, so taps on the code
  // still reach the code.
  @Test
  fun theButtonsNeverCoverTheFirstLineOfCode() {
    val tight = styleConfig(codeBlock = mapOf("fontSize" to 14.0, "padding" to 4.0))
    val view =
      CodeBlockContainerView(context, tight).apply {
        showsWrapButton = true
        applyCodeBlockNode(codeNode)
        measure(MeasureSpec.makeMeasureSpec(WIDTH_PX, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
        layout(0, 0, measuredWidth, measuredHeight)
      }
    val firstLineTop = firstLineTopOf(view)

    for (button in headerButtons(view).toList()) {
      assertTrue("${button.bottom} > $firstLineTop", button.bottom <= firstLineTop)
      assertTrue("inside the block", button.bottom <= view.height)
    }
  }

  private fun laidOutCodeBlock(showsWrapButton: Boolean): CodeBlockContainerView =
    CodeBlockContainerView(context, style).apply {
      this.showsWrapButton = showsWrapButton
      applyCodeBlockNode(codeNode)
      measure(MeasureSpec.makeMeasureSpec(WIDTH_PX, MeasureSpec.EXACTLY), MeasureSpec.makeMeasureSpec(0, MeasureSpec.UNSPECIFIED))
      layout(0, 0, measuredWidth, measuredHeight)
    }

  // The copy button, then the wrap button, by their icons (the labels come from props).
  private fun headerButtons(view: CodeBlockContainerView): Pair<AppCompatImageButton, AppCompatImageButton> {
    val buttons = (0 until view.childCount).map { view.getChildAt(it) }.filterIsInstance<AppCompatImageButton>()

    fun withIcon(name: String) = buttons.single { it.drawable.javaClass.simpleName == name }
    return withIcon("CopyIconDrawable") to withIcon("WrapIconDrawable")
  }

  private fun codePane(view: CodeBlockContainerView) =
    (0 until view.childCount).map { view.getChildAt(it) }.filterIsInstance<android.widget.HorizontalScrollView>().single()

  // The code pane's top plus the code text's top padding.
  private fun firstLineTopOf(view: CodeBlockContainerView): Int = codePane(view).let { it.top + it.getChildAt(0).paddingTop }

  // The header ends where the code pane starts.
  private fun headerHeightOf(view: CodeBlockContainerView): Int = codePane(view).top

  private fun bounds(view: View) = Rect(view.left, view.top, view.right, view.bottom)

  // The content inset: the code block style's padding plus its border.
  private fun CodeBlockContainerView.paddingForTest(): Int {
    val codeBlock = style.codeBlockStyle
    return kotlin.math.ceil(codeBlock.padding + codeBlock.borderWidth).toInt()
  }

  private companion object {
    const val WIDTH_PX = 1080
  }
}
