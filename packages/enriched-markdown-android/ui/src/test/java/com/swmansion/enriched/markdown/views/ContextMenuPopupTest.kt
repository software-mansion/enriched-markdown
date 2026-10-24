package com.swmansion.enriched.markdown.views

import android.app.Activity
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.PopupWindow
import android.widget.TextView
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class ContextMenuPopupTest {
  /** [PopupWindow.showAtLocation] needs a parent attached to a window token. */
  private fun newAttachedAnchor(): View {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    val root = FrameLayout(activity)
    activity.setContentView(root)
    val anchor = View(activity)
    root.addView(anchor, ViewGroup.LayoutParams(10, 10))
    return anchor
  }

  /** [ContextMenuPopup]'s active popup is process-wide state; leaking it into the next test breaks that test's own show(). */
  @After
  fun tearDown() {
    ContextMenuPopup.dismiss()
    shadowOf(Looper.getMainLooper()).idle()
  }

  /**
   * [ShadowPopupWindow][org.robolectric.shadows.ShadowPopupWindow] has no
   * `getLatestPopupWindow()` in the Robolectric version this module pins, so the
   * popup [show] just built is read back via reflection on ContextMenuPopup's
   * own private `activePopup` field instead.
   */
  private fun activePopupWindow(): PopupWindow? {
    val field = ContextMenuPopup::class.java.getDeclaredField("activePopup")
    field.isAccessible = true
    return field.get(ContextMenuPopup) as PopupWindow?
  }

  @Test
  fun `two item menu renders item, divider, item`() {
    val anchor = newAttachedAnchor()

    ContextMenuPopup.show(anchor, anchor) {
      item(ContextMenuPopup.Icon.COPY, "Copy") {}
      item(ContextMenuPopup.Icon.DOCUMENT, "Copy as Markdown") {}
    }

    val content = activePopupWindow()?.contentView as LinearLayout
    assertEquals(3, content.childCount)

    val firstItem = content.getChildAt(0) as LinearLayout
    val divider = content.getChildAt(1)
    val secondItem = content.getChildAt(2) as LinearLayout

    assertFalse(divider is LinearLayout)
    assertEquals("Copy", (firstItem.getChildAt(1) as TextView).text.toString())
    assertEquals("Copy as Markdown", (secondItem.getChildAt(1) as TextView).text.toString())
  }

  @Test
  fun `single item menu has no divider`() {
    val anchor = newAttachedAnchor()

    ContextMenuPopup.show(anchor, anchor) {
      item(ContextMenuPopup.Icon.COPY, "Copy") {}
    }

    val content = activePopupWindow()?.contentView as LinearLayout
    assertEquals(1, content.childCount)
  }

  @Test
  fun `empty builder shows nothing`() {
    val anchor = newAttachedAnchor()

    ContextMenuPopup.show(anchor, anchor) {}

    assertNull(activePopupWindow())
  }

  @Test
  fun `dismiss leaves no showing popup`() {
    val anchor = newAttachedAnchor()

    ContextMenuPopup.show(anchor, anchor) {
      item(ContextMenuPopup.Icon.COPY, "Copy") {}
    }
    val popup = activePopupWindow()
    assertTrue(popup?.isShowing == true)

    ContextMenuPopup.dismiss()

    assertFalse(popup?.isShowing == true)
    assertNull(activePopupWindow())
  }
}
