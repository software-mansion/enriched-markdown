package com.swmansion.enriched.markdown

import android.app.Activity
import android.content.Context
import android.view.View
import android.view.View.MeasureSpec
import android.widget.FrameLayout
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import org.robolectric.annotation.LooperMode

// #1196
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
@LooperMode(LooperMode.Mode.PAUSED)
class PendingLayoutScrollTest {
  // Like Fabric: never lays out its children.
  private class MountingParent(
    context: Context,
  ) : FrameLayout(context) {
    override fun onLayout(
      changed: Boolean,
      left: Int,
      top: Int,
      right: Int,
      bottom: Int,
    ) = Unit
  }

  private fun mount(
    view: View,
    width: Int,
    height: Int,
  ) {
    view.measure(
      MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
      MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY),
    )
    view.layout(0, 0, width, height)
  }

  @Test
  fun textSetBeforeTheNextDrawStartsAtItsFirstLine() {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    val parent = MountingParent(activity)
    val view = EnrichedMarkdownText(activity)
    parent.addView(view)
    activity.setContentView(parent)

    mount(view, WIDTH, 0)
    view.onPreDraw()
    assertTrue("TextView should scroll inside a 0 px frame", view.scrollY > 0)

    mount(view, WIDTH, HEIGHT)
    view.text = "First line\nSecond line"
    view.onPreDraw()

    assertEquals(0, view.scrollY)
  }

  private companion object {
    const val WIDTH = 1000
    const val HEIGHT = 500
  }
}
