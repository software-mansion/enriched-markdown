package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.view.View
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// The shadow node measures a slot at the height it reserved, so the layout the view publishes for
// it to take must not depend on how far a slot has grown in.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class ReservedSlotLayoutTest {
  private class Stack(
    context: Context,
  ) : ContainerNodeView(context) {
    fun add(view: View) {
      segmentViews.add(view)
      addView(view)
    }

    fun lay() {
      layout(0, 0, 400, 10_000)
      layoutSegments()
    }
  }

  private class Block(
    context: Context,
    private val heightPx: Int,
  ) : View(context) {
    override fun onMeasure(
      widthMeasureSpec: Int,
      heightMeasureSpec: Int,
    ) = setMeasuredDimension(MeasureSpec.getSize(widthMeasureSpec), heightPx)
  }

  @Test
  fun aSlotGrowingInPublishesItsReservedHeight() {
    val context = RuntimeEnvironment.getApplication()
    val style = styleConfig()
    val stack = Stack(context)
    val growing = BlockSlotSegmentView(context, style, "code:a", BlockSlotKind.CODE).apply { slotHeight = 200 }
    val after = BlockSlotSegmentView(context, style, "code:b", BlockSlotKind.CODE).apply { slotHeight = 80 }
    stack.add(Block(context, 50))
    stack.add(growing)
    stack.add(Block(context, 30))
    stack.add(after)

    growing.revealFraction = 1f
    stack.lay()
    val grown = stack.reservedSlotLayout()
    val grownTop = after.top

    growing.revealFraction = 0.5f
    stack.lay()
    assertNotEquals(grownTop, after.top)
    assertEquals(grown, stack.reservedSlotLayout())
  }
}
