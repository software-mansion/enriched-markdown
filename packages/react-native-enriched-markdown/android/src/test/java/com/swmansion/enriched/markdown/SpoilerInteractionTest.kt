package com.swmansion.enriched.markdown

import android.text.Spannable
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup
import com.swmansion.enriched.markdown.parser.MarkdownASTNode
import com.swmansion.enriched.markdown.renderer.Renderer
import com.swmansion.enriched.markdown.spans.SpoilerSpan
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayMode
import com.swmansion.enriched.markdown.test.MarkdownRenderTestSupport.styleConfig
import com.swmansion.enriched.markdown.test.TestAstFactory.link
import com.swmansion.enriched.markdown.test.TestAstFactory.paragraph
import com.swmansion.enriched.markdown.test.TestAstFactory.spoiler
import com.swmansion.enriched.markdown.test.TestAstFactory.text
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

/** Tapping spoilers through the text view's movement method. Ported from the library's SpoilerInteractionTest. */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SpoilerInteractionTest {
  private val context = RuntimeEnvironment.getApplication()
  private val pressedLinks = mutableListOf<String>()

  private fun laidOutView(block: MarkdownASTNode): EnrichedMarkdownInternalText {
    val renderer = Renderer().apply { configure(styleConfig(), context) }
    val view = EnrichedMarkdownInternalText(context)
    view.layoutParams = ViewGroup.LayoutParams(WIDTH, ViewGroup.LayoutParams.WRAP_CONTENT)
    view.applyStyledText(renderer.renderContent(listOf(block), onLinkPress = { pressedLinks.add(it) }))
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
    val view = laidOutView(paragraph(text("plain "), spoiler(text("secret"))))
    val x = view.xOf("secret")

    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x)

    assertTrue(view.spoiler.revealing || view.spoiler.revealed)
  }

  @Test
  fun aGestureThatOnlyEndsOnASpoilerDoesNotRevealIt() {
    val view = laidOutView(paragraph(text("plain words "), spoiler(text("secret"))))

    view.send(MotionEvent.ACTION_DOWN, view.xOf("plain"))
    view.send(MotionEvent.ACTION_MOVE, view.xOf("secret"))
    view.send(MotionEvent.ACTION_UP, view.xOf("secret"))

    assertFalse(view.spoiler.revealing || view.spoiler.revealed)
  }

  @Test
  fun aLongPressOnASpoilerDoesNotRevealIt() {
    val view = laidOutView(paragraph(spoiler(text("secret"))))
    val x = view.xOf("secret")
    val held = ViewConfiguration.getLongPressTimeout().toLong() + 1

    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x, eventTime = held)

    assertFalse(view.spoiler.revealing || view.spoiler.revealed)
  }

  @Test
  fun aLinkUnderAConcealedSpoilerOnlyWorksOnceRevealed() {
    val view = laidOutView(paragraph(spoiler(link("https://example.com", text("secret")))))
    val x = view.xOf("secret")

    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x)
    assertEquals("The first tap only reveals", emptyList<String>(), pressedLinks)

    view.spoiler.markRevealed()
    view.send(MotionEvent.ACTION_DOWN, x)
    view.send(MotionEvent.ACTION_UP, x)
    assertEquals(listOf("https://example.com"), pressedLinks)
  }

  @Test
  fun theOverlayPropReachesAnExistingDrawer() {
    val view = laidOutView(paragraph(spoiler(text("secret"))))
    val drawer = assertNotNullDrawer(view)
    assertEquals(SpoilerOverlayMode.PARTICLES, drawer.overlayMode)

    view.spoilerOverlay = SpoilerOverlayMode.SOLID

    assertEquals(SpoilerOverlayMode.SOLID, drawer.overlayMode)
  }

  @Test
  fun aDetachedViewKeepsItsDrawer() {
    val view = laidOutView(paragraph(spoiler(text("secret"))))
    val drawer = assertNotNullDrawer(view)

    view.onDetachedFromWindowForTest()

    assertEquals("The text stays concealed, so its overlay has to come back", drawer, view.spoilerOverlayDrawer)
  }

  private fun assertNotNullDrawer(view: EnrichedMarkdownInternalText) = view.spoilerOverlayDrawer.also { assertNotNull(it) }!!

  private fun EnrichedMarkdownInternalText.onDetachedFromWindowForTest() {
    val method = View::class.java.getDeclaredMethod("onDetachedFromWindow")
    method.isAccessible = true
    method.invoke(this)
  }

  private companion object {
    const val WIDTH = 800
  }
}
