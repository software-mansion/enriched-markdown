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
  ): Long? {
    val props =
      JavaOnlyMap.of("markdown", markdown, "markdownStyle", JavaOnlyMap(), "allowTrailingMargin", trailingMargin, "streaming", streaming)
    props.putMap("streamingConfig", streamingConfig ?: JavaOnlyMap.of("smooth", smooth))
    return MeasurementStore.laidOutSizeForStreamUpdate(viewId, width, measureInputOf(props), true, true, 1f, 0f, density, rtl)
  }

  private fun recordMeasured(size: Long) = MeasurementStore.recordMeasured(viewId, size)

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
  fun withoutALaidOutSizeEvenAStreamUpdateMeasuresInFull() {
    streamUpdate("Streaming")
    assertNull(streamUpdate("Streaming on"))
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
