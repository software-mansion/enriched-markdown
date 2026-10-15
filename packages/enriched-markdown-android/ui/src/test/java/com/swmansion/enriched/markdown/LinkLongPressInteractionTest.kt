package com.swmansion.enriched.markdown

import android.app.Activity
import android.os.Looper
import android.view.MotionEvent
import android.view.ViewConfiguration
import android.widget.FrameLayout
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.plugin.PluginSnapshot
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.defaultStyle
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.Duration

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LinkLongPressInteractionTest {
  private val linkLongPresses = mutableListOf<String>()
  private var viewLongClicks = 0

  /** Attached to a window: View only runs its own long-press callback while attached. */
  private fun attachedView(document: MarkdownASTNode): EnrichedMarkdownInternalText {
    val activity = Robolectric.buildActivity(Activity::class.java).setup().get()
    val view = EnrichedMarkdownInternalText(activity)
    val renderer = Renderer().apply { configure(defaultStyle, activity, plugins = PluginSnapshot.EMPTY) }
    view.applyStyledText(renderer.renderDocument(document, null) { url -> linkLongPresses += url })
    // Stands in for the text selection or block context menu a host opens on long-click.
    view.setOnLongClickListener {
      viewLongClicks++
      true
    }
    activity.setContentView(view, FrameLayout.LayoutParams(WIDTH, FrameLayout.LayoutParams.WRAP_CONTENT))
    shadowOf(Looper.getMainLooper()).idle()
    return view
  }

  private fun EnrichedMarkdownInternalText.xOf(substring: String): Float {
    val start = text.indexOf(substring)
    val layout = requireNotNull(layout)
    return totalPaddingLeft + (layout.getPrimaryHorizontal(start) + layout.getPrimaryHorizontal(start + substring.length)) / 2f
  }

  private fun EnrichedMarkdownInternalText.longPress(x: Float) {
    val y = totalPaddingTop + requireNotNull(layout).getLineBaseline(0) - 2f
    val holdMs = ViewConfiguration.getLongPressTimeout() + 100L
    dispatch(MotionEvent.ACTION_DOWN, x, y, 0L)
    shadowOf(Looper.getMainLooper()).idleFor(Duration.ofMillis(holdMs))
    dispatch(MotionEvent.ACTION_UP, x, y, holdMs)
  }

  private fun EnrichedMarkdownInternalText.dispatch(
    action: Int,
    x: Float,
    y: Float,
    eventTime: Long,
  ) {
    val event = MotionEvent.obtain(0L, eventTime, action, x, y, 0)
    dispatchTouchEvent(event)
    event.recycle()
  }

  @Test
  fun aLongPressOnALinkFiresOnlyTheLinkLongPress() {
    val view = attachedView(document(paragraph(text("see "), link("https://example.com", text("docs")))))

    view.longPress(view.xOf("docs"))

    assertEquals(listOf("https://example.com"), linkLongPresses)
    assertEquals(0, viewLongClicks)
  }

  @Test
  fun aLongPressOnPlainTextStillReachesTheView() {
    val view = attachedView(document(paragraph(text("plain words "), link("https://example.com", text("docs")))))

    view.longPress(view.xOf("plain"))

    assertEquals(emptyList<String>(), linkLongPresses)
    assertEquals(1, viewLongClicks)
  }

  private companion object {
    const val WIDTH = 1080
  }
}
