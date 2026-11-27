package com.swmansion.enriched.markdown.utils.text.view

import android.graphics.Color
import android.widget.EditText
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class SelectionHandleColorTest {
  // Clearing the color must hand the handles back to the theme's tint, not leave them untinted (#1162).
  @Test
  fun removingTheColorRestoresTheThemedHandles() {
    val view = EditText(RuntimeEnvironment.getApplication())
    val handles = { listOf(view.textSelectHandleLeft, view.textSelectHandle, view.textSelectHandleRight) }

    view.applySelectionHandleColor(Color.RED)
    handles().forEach { assertNotNull(it!!.colorFilter) }

    view.applySelectionHandleColor(null)
    handles().forEach { assertNull(it!!.colorFilter) }
  }
}
