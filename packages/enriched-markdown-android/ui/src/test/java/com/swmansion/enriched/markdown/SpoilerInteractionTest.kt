package com.swmansion.enriched.markdown

import android.content.Context
import android.text.Spannable
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.render
import com.swmansion.enriched.markdown.test.TestAstFactory.document
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.spoiler
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpoilerInteractionTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private fun laidOutView(document: MarkdownASTNode): EnrichedMarkdownInternalText {
    val view = EnrichedMarkdownInternalText(context)
    view.layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.applyStyledText(render(document))
    view.measure(
      View.MeasureSpec.makeMeasureSpec(WIDTH, View.MeasureSpec.EXACTLY),
      View.MeasureSpec.makeMeasureSpec(0, View.MeasureSpec.UNSPECIFIED),
    )
    view.layout(0, 0, WIDTH, view.measuredHeight)
    return view
  }

  private val EnrichedMarkdownInternalText.spoiler: SpoilerSpan
    get() = (text as Spannable).getSpans(0, text.length, SpoilerSpan::class.java).single()

  /** Horizontal center of [substring] on the first line. */
  private fun EnrichedMarkdownInternalText.xOf(substring: String): Float {
    val start = text.indexOf(substring)
    val layout = requireNotNull(layout)
    return totalPaddingLeft + (layout.getPrimaryHorizontal(start) + layout.getPrimaryHorizontal(start + substring.length)) / 2f
  }

  private fun EnrichedMarkdownInternalText.firstLineY(): Float = totalPaddingTop + requireNotNull(layout).getLineBaseline(0) - 2f

  private fun EnrichedMarkdownInternalText.send(
    action: Int,
    x: Float,
    downTime: Long = 0L,
    eventTime: Long = 0L,
  ) {
    val event = MotionEvent.obtain(downTime, eventTime, action, x, firstLineY(), 0)
    movementMethod.onTouchEvent(this, text as Spannable, event)
    event.recycle()
  }

  @Test
  fun aTapOnAConcealedSpoilerRevealsIt() {
    val view = laidOutView(document(paragraph(text("plain "), spoiler(text("secret")))))
    val x = view.xOf("secret")

    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x)

    assertTrue(view.spoiler.revealing || view.spoiler.revealed)
  }

  @Test
  fun aGestureThatOnlyEndsOnASpoilerDoesNotRevealIt() {
    val view = laidOutView(document(paragraph(text("plain words "), spoiler(text("secret")))))

    view.send(MotionEvent.ACTION_DOWN, view.xOf("plain"))
    view.send(MotionEvent.ACTION_MOVE, view.xOf("secret"))
    view.send(MotionEvent.ACTION_UP, view.xOf("secret"))

    assertFalse(view.spoiler.revealing || view.spoiler.revealed)
  }

  @Test
  fun aLongPressOnASpoilerDoesNotRevealIt() {
    val view = laidOutView(document(paragraph(spoiler(text("secret")))))
    val x = view.xOf("secret")
    val held = ViewConfiguration.getLongPressTimeout().toLong() + 1

    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x, eventTime = held)

    assertFalse(view.spoiler.revealing || view.spoiler.revealed)
  }

  @Test
  fun aLinkUnderAConcealedSpoilerOnlyWorksOnceRevealed() {
    val view = laidOutView(document(paragraph(spoiler(link("https://example.com", text("secret"))))))
    val pressed = mutableListOf<String>()
    view.onLinkPressCallback = { pressed.add(it) }
    val x = view.xOf("secret")

    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x)
    assertEquals("The first tap only reveals", emptyList<String>(), pressed)

    view.spoiler.markRevealed()
    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x)
    assertEquals(listOf("https://example.com"), pressed)
  }

  private companion object {
    const val WIDTH = 800
  }
}
