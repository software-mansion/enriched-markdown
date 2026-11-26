package com.swmansion.enriched.markdown

import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.bridge.ReadableMap
import com.facebook.yoga.YogaMeasureOutput
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class StreamMeasurementTest {
  private val viewId = 48213
  private val widthPx = 1008f
  private val laidOut = YogaMeasureOutput.make(360f, 2400f)

  @After
  fun releaseView() = MeasurementStore.release(viewId)

  // The full measurement path renders through the native parser, which the JVM lacks,
  // so the stream check runs on its own.
  private fun streamUpdate(
    markdown: String,
    width: Float = widthPx,
    trailingMargin: Boolean = false,
    streamingConfig: ReadableMap? = null,
    smooth: Boolean = false,
    density: Float = 1f,
    rtl: Boolean = false,
    streaming: Boolean = true,
    withheld: Boolean = false,
    onFilter: () -> Unit = {},
  ): Long? {
    val props =
      JavaOnlyMap.of("markdown", markdown, "markdownStyle", JavaOnlyMap(), "allowTrailingMargin", trailingMargin, "streaming", streaming)
    props.putMap("streamingConfig", streamingConfig ?: JavaOnlyMap.of("smooth", smooth))
    return MeasurementStore.laidOutSizeForStreamUpdate(viewId, width, measureInputOf(props), true, true, 1f, 0f, density, rtl) {
      onFilter()
      withheld
    }
  }

  private fun recordMeasured(
    size: Long,
    width: Float = widthPx,
  ) = MeasurementStore.recordMeasured(viewId, width, size)

  private fun revealedSize(
    markdown: String,
    smooth: Boolean,
    full: Long,
    width: Float = widthPx,
  ): Long? {
    val props: ReadableMap = JavaOnlyMap.of("markdown", markdown, "streamingConfig", JavaOnlyMap.of("smooth", smooth))
    val check =
      MeasurementStore::class.java.getDeclaredMethod(
        "revealedSize",
        Int::class.javaObjectType,
        Float::class.javaPrimitiveType,
        MeasureInput::class.java,
        Long::class.javaPrimitiveType,
      )
    check.isAccessible = true
    return check.invoke(MeasurementStore, viewId, width, measureInputOf(props), full) as Long?
  }

  @Test
  fun withSlotsSmoothPacingTakesTheHeightTheViewRevealed() {
    val full = YogaMeasureOutput.make(360f, 3000f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    assertEquals(YogaMeasureOutput.make(360f, 2400f), revealedSize("Streaming **markdown**", smooth = true, full))

    assertNull(revealedSize("Streaming **markdown**", smooth = false, full))
    assertNull(revealedSize("Streaming **markdown**", smooth = true, full, width = 720f))
    assertNull(revealedSize("Other text", smooth = true, full))
    // Once the view shows all of it, the whole document's measurement stands.
    assertNull(revealedSize("Streaming **mark", smooth = true, full))
  }

  @Test
  fun aStreamUpdateTakesTheSizeTheViewLaidOut() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    assertNull(streamUpdate("Streaming **mark"))

    assertEquals(laidOut, streamUpdate("Streaming **markdown**"))
    // Measured again before the view rendered it: what the previous measurement returned.
    assertEquals(laidOut, streamUpdate("Streaming **markdown**"))
  }

  // Another density or layout direction lays the text out anew, though the props are the same.
  @Test
  fun aDensityOrDirectionChangeMeasuresInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    assertNull(streamUpdate("Streaming **markdown**", density = 2f))
    assertNull(streamUpdate("Streaming **markdown** text", density = 2f, rtl = true))
    assertEquals(laidOut, streamUpdate("Streaming **markdown** text and", density = 2f, rtl = true))
  }

  // Yoga measures twice a pass: right after new content measured in full, the view
  // still shows the previous document, so its size must not answer the second call.
  @Test
  fun theSameDocumentAgainTakesWhatItsMeasurementReturned() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Old message")
    streamUpdate("Old message")
    assertNull(streamUpdate("New message"))
    val measured = YogaMeasureOutput.make(360f, 80f)
    recordMeasured(measured)

    assertEquals(measured, streamUpdate("New message"))
  }

  @Test
  fun theSameDocumentAgainTakesTheViewsSizeOnceItLaidItOut() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Message")
    streamUpdate("Message")
    recordMeasured(YogaMeasureOutput.make(360f, 80f))
    // An image settled, say: the view laid the same document out taller and asked again.
    val taller = YogaMeasureOutput.make(360f, 300f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, taller, "Message")

    assertEquals(taller, streamUpdate("Message"))
  }

  // Smooth pacing: the view shows part of the markdown and asks again as it shows more.
  @Test
  fun aViewShowingPartOfTheDocumentHandsOverEachNewSize() {
    streamUpdate("Smooth pacing", smooth = true)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Smooth pacing shows")
    assertEquals(laidOut, streamUpdate("Smooth pacing shows the words", smooth = true))
    val taller = YogaMeasureOutput.make(360f, 2480f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, taller, "Smooth pacing shows the")

    assertEquals(taller, streamUpdate("Smooth pacing shows the words", smooth = true))
  }

  // Two updates arrive before the view renders the first; it then lays that one out a line taller
  // and the stream pauses. The answer was the view's own size, so its newer size replaces it.
  @Test
  fun aStreamThatPausesTakesTheViewsSizeOnceItCatchesUp() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming")
    streamUpdate("Streaming")
    assertEquals(laidOut, streamUpdate("Streaming **mark"))
    assertEquals(laidOut, streamUpdate("Streaming **markdown**"))
    val taller = YogaMeasureOutput.make(360f, 2480f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, taller, "Streaming **mark")

    assertEquals(taller, streamUpdate("Streaming **markdown**"))
  }

  // Without smooth pacing an earlier state the view still shows is a render in flight, not an answer.
  @Test
  fun theSameDocumentAgainKeepsItsAnswerWhileTheViewCatchesUp() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming")
    streamUpdate("Streaming")
    streamUpdate("Streaming **markdown**", trailingMargin = true)
    val measured = YogaMeasureOutput.make(360f, 3000f)
    recordMeasured(measured)

    assertEquals(measured, streamUpdate("Streaming **markdown**", trailingMargin = true))
  }

  // A new stream's first chunks arrive before the view rendered any of them: it still
  // shows the document the stream replaced, whose size isn't the stream's.
  @Test
  fun aNewStreamDoesntTakeTheSizeOfTheDocumentItReplaced() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "The whole previous document")
    streamUpdate("The whole previous document")
    assertNull(streamUpdate("New"))
    recordMeasured(YogaMeasureOutput.make(360f, 20f))

    assertNull(streamUpdate("New stream"))
  }

  @Test
  fun newContentAnotherWidthOrAnotherLayoutMeasureInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "First message")
    streamUpdate("First message")

    assertNull(streamUpdate("Second message"))
    assertNull(streamUpdate("Second message, longer", width = 700f))
    assertNull(streamUpdate("Second message, longer still", trailingMargin = true))
  }

  @Test
  fun anotherAnimationKeepsTheStreamUpdateButAnotherModeMeasuresInFull() {
    fun config(
      animation: String,
      tableMode: String = "progressive",
    ) = JavaOnlyMap.of("tableMode", tableMode, "animation", animation)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark", streamingConfig = config("fade"))

    assertEquals(laidOut, streamUpdate("Streaming **markdown", streamingConfig = config("none")))
    assertNull(streamUpdate("Streaming **markdown**", streamingConfig = config("none", tableMode = "hidden")))
  }

  // A detached view clears its size: it lays nothing out until it is attached again.
  @Test
  fun aClearedLaidOutSizeMeasuresTheStreamInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming")
    streamUpdate("Streaming")
    MeasurementStore.clearLaidOutSize(viewId)

    assertNull(streamUpdate("Streaming **markdown**"))
  }

  @Test
  fun textAppendedWithoutStreamingMeasuresInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Show")
    streamUpdate("Show", streaming = false)

    assertNull(streamUpdate("Show more", streaming = false))
  }

  @Test
  fun theEndOfAStreamAndItsRepeatsTakeTheSizeTheViewLaidOut() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")

    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
    // Yoga measures again, and the view asks again once it laid the end out.
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
    MeasurementStore.storeLaidOutSize(viewId, widthPx, YogaMeasureOutput.make(360f, 2500f), "Streaming **markdown**")
    assertEquals(YogaMeasureOutput.make(360f, 2500f), streamUpdate("Streaming **markdown**", streaming = false))
    // Later text is no end: it measures in full.
    assertNull(streamUpdate("Streaming **markdown** more", streaming = false))
  }

  @Test
  fun anEndWithTheMarkdownOfTheLastUpdateKeepsTheSizeTheViewLaidOut() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    streamUpdate("Streaming **markdown**")

    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
  }

  // Nothing to check the last measurement against: the end measures in full, its repeats take that.
  @Test
  fun anEndWithoutALaidOutSizeMeasuresInFull() {
    streamUpdate("Streaming **markdown**")
    recordMeasured(YogaMeasureOutput.make(360f, 1000f))

    assertNull(streamUpdate("Streaming **markdown**", streaming = false))
    val full = YogaMeasureOutput.make(360f, 1100f)
    recordMeasured(full)
    assertEquals(full, streamUpdate("Streaming **markdown**", streaming = false))
  }

  // Yoga measures at the flex basis and at the width the node gets: the end takes the stream's
  // update at both.
  @Test
  fun theEndTakesTheViewsSizeOnlyAtTheWidthItLaidOutAt() {
    val narrow = 700f
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark", width = narrow)
    streamUpdate("Streaming **mark")
    streamUpdate("Streaming **markdown**", width = narrow)
    streamUpdate("Streaming **markdown**")

    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
    // The size the view laid out is for one width; the other measures in full.
    assertNull(streamUpdate("Streaming **markdown**", width = narrow, streaming = false))
  }

  // The end keeps the layout key, so a stream that goes on after it is an update, and another answer isn't.
  @Test
  fun aStreamThatGoesOnAfterTheEndTakesAnUpdate() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))

    assertEquals(laidOut, streamUpdate("Streaming **markdown** and more"))
    assertNull(streamUpdate("Another answer"))
  }

  // The view shows less than the end when streaming held back a table, a code block or media.
  @Test
  fun anEndAfterStreamingHeldBackABlockMeasuresInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")

    assertNull(streamUpdate("Streaming **markdown**", streaming = false, withheld = true))
    // Yoga measures again, and the view's size still lacks the block.
    assertNull(streamUpdate("Streaming **markdown**", streaming = false, withheld = true))
  }

  @Test
  fun textAppendedAfterTheEndMeasuresInFullAtEveryWidth() {
    val narrow = 700f
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark", width = narrow)
    streamUpdate("Streaming **mark")
    streamUpdate("Streaming **markdown**", width = narrow)
    streamUpdate("Streaming **markdown**")
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))

    // The entry left from streaming at the other width doesn't make later text an end.
    assertNull(streamUpdate("Streaming **markdown** more", width = narrow, streaming = false))
  }

  @Test
  fun theEndFollowsWhatTheViewRevealsWithSmoothPacing() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark", smooth = true)
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", smooth = true, streaming = false))

    val revealed = YogaMeasureOutput.make(360f, 2600f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, revealed, "Streaming **markdown")
    assertEquals(revealed, streamUpdate("Streaming **markdown**", smooth = true, streaming = false))
  }

  @Test
  fun aSecondStreamTakesTheViewsSizeAtItsEnd() {
    val narrow = 700f
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "One **mark")
    streamUpdate("One **mark", width = narrow)
    streamUpdate("One **mark")
    streamUpdate("One **markdown**", width = narrow)
    streamUpdate("One **markdown**")
    streamUpdate("One **markdown**", width = narrow, streaming = false)
    streamUpdate("One **markdown**", streaming = false)

    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Two **mark")
    streamUpdate("Two **mark")
    assertEquals(laidOut, streamUpdate("Two **markdown**"))
    assertEquals(laidOut, streamUpdate("Two **markdown**", streaming = false))
  }

  // The end's commit may change more than `streaming`: that measures in full.
  @Test
  fun anotherPropInTheEndCommitMeasuresInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")

    assertNull(streamUpdate("Streaming **markdown**", trailingMargin = true, streaming = false))
  }

  @Test
  fun theFilterIsAskedOncePerEnd() {
    var asked = 0
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    repeat(3) { streamUpdate("Streaming **markdown**", streaming = false, onFilter = { asked += 1 }) }

    assertEquals(1, asked)
  }

  private fun endAStream() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
  }

  @Test
  fun aWidthAfterTheEndMeasuresInFull() {
    endAStream()

    assertNull(streamUpdate("Streaming **markdown**", width = 700f, streaming = false))
  }

  @Test
  fun aDensityAfterTheEndMeasuresInFull() {
    endAStream()

    assertNull(streamUpdate("Streaming **markdown**", density = 2f, streaming = false))
  }

  @Test
  fun aDirectionAfterTheEndMeasuresInFull() {
    endAStream()

    assertNull(streamUpdate("Streaming **markdown**", rtl = true, streaming = false))
  }

  @Test
  fun aViewMeasuresInFullAfterItIsReleased() {
    endAStream()
    MeasurementStore.release(viewId)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **markdown**")

    assertNull(streamUpdate("Streaming **markdown**", streaming = false))
  }

  @Test
  fun anotherLayoutAfterTheEndMeasuresInFull() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))

    assertNull(streamUpdate("Streaming **markdown**", trailingMargin = true, streaming = false))
  }

  @Test
  fun withoutALaidOutSizeEvenAStreamUpdateMeasuresInFull() {
    streamUpdate("Streaming")
    assertNull(streamUpdate("Streaming on"))
  }

  // Measured with an upper limit of 320 px, the view hugs its widest line and lays out at 304.
  @Test
  fun aViewHuggingItsContentTakesTheShortcut() {
    var markdown = "Hi"
    streamUpdate(markdown, width = 320f)
    MeasurementStore.storeLaidOutSize(viewId, 304f, laidOut, markdown, fitsWiderWidths = true)
    repeat(10) {
      markdown += " there"
      assertEquals(laidOut, streamUpdate(markdown, width = 320f))
      MeasurementStore.storeLaidOutSize(viewId, 304f, laidOut, markdown, fitsWiderWidths = true)
    }
  }

  // A view narrower than it was measured at publishes a size for its own width only. Its end has
  // nothing to check the stream's last answer against, so it measures in full; the end's repeats
  // take that answer, until an image that loads or fails changes the content (#1222).
  @Test
  fun aNarrowerViewsEndMeasuresInFullAndAgainAfterAContentResize() {
    val markdown = "The build is ![passing](https://example.com/x.png) and the rest wraps."
    streamUpdate(markdown, width = 320f)
    recordMeasured(YogaMeasureOutput.make(360f, 1000f), width = 320f)
    MeasurementStore.storeLaidOutSize(viewId, 280f, laidOut, markdown)

    assertNull(streamUpdate(markdown, width = 320f, streaming = false))
    val full = YogaMeasureOutput.make(360f, 1100f)
    recordMeasured(full, width = 320f)
    assertEquals(full, streamUpdate(markdown, width = 320f, streaming = false))

    MeasurementStore.storeLaidOutSize(viewId, 280f, YogaMeasureOutput.make(280f, 1200f), markdown)
    MeasurementStore.invalidateForContentResize(viewId)
    assertNull(streamUpdate(markdown, width = 320f, streaming = false))
  }

  @Test
  fun aNarrowerViewsContentResizeWhileStreamingMeasuresTheNextUpdateInFull() {
    streamUpdate("Streaming **mark", width = 320f)
    recordMeasured(YogaMeasureOutput.make(360f, 1000f), width = 320f)
    MeasurementStore.storeLaidOutSize(viewId, 280f, laidOut, "Streaming **mark")
    MeasurementStore.invalidateForContentResize(viewId)

    assertNull(streamUpdate("Streaming **mark", width = 320f))
  }

  // A view at the measured width has just published its new size: the stream takes it, as on main.
  @Test
  fun aContentResizeAtTheMeasuredWidthKeepsTheStreamUpdate() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    recordMeasured(laidOut)
    val resized = YogaMeasureOutput.make(360f, 2600f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, resized, "Streaming **mark")
    MeasurementStore.invalidateForContentResize(viewId)

    assertEquals(resized, streamUpdate("Streaming **mark"))
    assertEquals(resized, streamUpdate("Streaming **mark", streaming = false))
  }

  // Resizes come in bursts (every span of a failed image reports), after the render's own invalidate.
  @Test
  fun repeatedContentResizesAtTheMeasuredWidthKeepTheStreamUpdate() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    recordMeasured(laidOut)
    val resized = YogaMeasureOutput.make(360f, 2600f)
    MeasurementStore.storeLaidOutSize(viewId, widthPx, resized, "Streaming **mark")
    MeasurementStore.invalidate(viewId)
    MeasurementStore.invalidateForContentResize(viewId)
    MeasurementStore.invalidateForContentResize(viewId)

    assertEquals(resized, streamUpdate("Streaming **mark"))
  }

  // The end's own height update invalidates the store too, and must keep the shortcut.
  @Test
  fun aPlainInvalidateKeepsTheEndsShortcut() {
    MeasurementStore.storeLaidOutSize(viewId, widthPx, laidOut, "Streaming **mark")
    streamUpdate("Streaming **mark")
    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
    MeasurementStore.invalidate(viewId)

    assertEquals(laidOut, streamUpdate("Streaming **markdown**", streaming = false))
  }

  // A line that now wraps at the view's width might not at the measured one.
  @Test
  fun aHuggingViewWhoseTextWrapsMeasuresInFull() {
    MeasurementStore.storeLaidOutSize(viewId, 304f, laidOut, "Hi", fitsWiderWidths = true)
    streamUpdate("Hi", width = 320f)
    assertEquals(laidOut, streamUpdate("Hi there", width = 320f))
    MeasurementStore.storeLaidOutSize(viewId, 304f, YogaMeasureOutput.make(304f, 2480f), "Hi there")

    assertNull(streamUpdate("Hi there", width = 320f))
    // Nor does a size laid out for any wider width serve a narrower one.
    MeasurementStore.storeLaidOutSize(viewId, 304f, laidOut, "Hi there", fitsWiderWidths = true)
    assertNull(streamUpdate("Hi there, you", width = 280f))
  }

  // A row's flexShrink text: Yoga measures its flex basis, then the width it shrinks to.
  @Test
  fun aNodeMeasuredAtItsBasisAndItsWidthTakesTheShortcutAtItsWidth() {
    for (basis in listOf(Float.POSITIVE_INFINITY, 1080f)) {
      var markdown = "Hi"
      repeat(10) { update ->
        markdown += " there"
        if (streamUpdate(markdown, width = basis) == null) recordMeasured(YogaMeasureOutput.make(900f, 40f), basis)
        val atWidth = streamUpdate(markdown, width = 320f)
        if (update > 0) assertEquals("basis $basis, update $update", laidOut, atWidth)
        if (atWidth == null) recordMeasured(laidOut, 320f)
        MeasurementStore.storeLaidOutSize(viewId, 320f, laidOut, markdown)
      }
      MeasurementStore.release(viewId)
    }
  }

  @Test
  fun onlyMarkdownThatKeepsAllOfThePreviousExtendsIt() {
    assertTrue(MeasurementStore.markdownExtends("Same", "Same and more"))
    assertFalse(MeasurementStore.markdownExtends("Streaming", "Streamed"))
    assertFalse(MeasurementStore.markdownExtends("", "First chunk"))
  }

  @Test
  fun chooseMeasurementTakesTheLaidOutSizeOnlyForAStreamUpdate() {
    val choose = MeasurementStore::chooseMeasurement
    assertEquals(MeasurementStore.MeasurementSource.LAID_OUT, choose(true, true, false, true, true))
    assertEquals(MeasurementStore.MeasurementSource.LAID_OUT, choose(true, false, true, true, true))
    assertEquals(MeasurementStore.MeasurementSource.FULL, choose(false, true, true, true, true))
  }

  @Test
  fun chooseMeasurementNeverGivesAGrownDocumentThePreviousAnswer() {
    val choose = MeasurementStore::chooseMeasurement
    assertEquals(MeasurementStore.MeasurementSource.PREVIOUS, choose(true, false, false, true, true))
    assertEquals(MeasurementStore.MeasurementSource.PREVIOUS, choose(true, false, false, false, true))
    assertEquals(MeasurementStore.MeasurementSource.FULL, choose(true, true, false, false, true))
    assertEquals(MeasurementStore.MeasurementSource.FULL, choose(true, false, false, false, false))
  }
}
