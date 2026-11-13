package com.swmansion.enriched.markdown

import android.graphics.Paint
import android.text.DynamicLayout
import android.text.Layout
import android.text.SpannableStringBuilder
import android.text.TextPaint
import com.facebook.react.uimanager.DisplayMetricsHolder
import com.swmansion.enriched.markdown.utils.common.BreakStrategyUtils
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode

// A streaming view stores its size from its own layout, which reflowed only the patched tail
// (MeasurementStore.storeLaidOut): it must come out as measuring the whole text does.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class LaidOutMeasurementTest {
  private val viewId = 48214
  private val referenceId = 48215
  private val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { textSize = 40f }

  private val words = "streamed text that wraps over several lines of the view as it keeps on growing".split(" ")
  private val growing = (1..words.size).map { words.take(it).joinToString(" ") }
  private val whole = growing.last()

  // A wide paragraph growing a word at a time, a short one, a third growing, then the third
  // gone again, as when a block that showed as text completes into nothing.
  private val states: List<String> = growing + "$whole\nok" + growing.map { "$whole\nok\n$it" } + "$whole\nok"

  @Before
  fun initDisplayMetrics() {
    DisplayMetricsHolder.initDisplayMetricsIfNotInitialized(RuntimeEnvironment.getApplication())
  }

  @After
  fun release() {
    MeasurementStore.release(viewId)
    MeasurementStore.release(referenceId)
  }

  // As a measurement at [width] would leave it: the store lays out for the width it offered.
  private fun measureAt(
    id: Int,
    width: Float = WIDTH.toFloat(),
  ) {
    MeasurementStore.store(id, "", paint)
    MeasurementStore.data.computeIfPresent(id) { _, entry -> entry.copy(cachedWidth = width) }
  }

  private fun storedSize(id: Int): Long = MeasurementStore.data.getValue(id).cachedSize

  // Built as the measurement builds its StaticLayout.
  @Suppress("WrongConstant")
  private fun layoutOf(
    text: SpannableStringBuilder,
    width: Int = WIDTH,
  ): Layout =
    DynamicLayout.Builder
      .obtain(text, paint, width)
      .setIncludePad(false)
      .setLineSpacing(0f, 1f)
      .setBreakStrategy(BreakStrategyUtils.resolveBreakStrategy(null))
      .setUseLineSpacingFromFallbacks(true)
      .build()

  @Test
  fun aLayoutPatchedOnStoresTheSizeOfTheWholeText() {
    measureAt(viewId)
    measureAt(referenceId)
    val text = SpannableStringBuilder()
    val layout = layoutOf(text)
    for (state in states) {
      // Patched from the paragraph the two texts first differ in, as a stream re-renders its last block.
      val common = text.toString().commonPrefixWith(state).length
      val start = if (common == 0) 0 else text.lastIndexOf('\n', common - 1) + 1
      text.replace(start, text.length, state.substring(start))

      assertNotNull(MeasurementStore.storeLaidOut(viewId, layout, start, TRAILING_MARGIN_PX, state))
      MeasurementStore.store(referenceId, SpannableStringBuilder(state), paint, TRAILING_MARGIN_PX)
      assertEquals(state, storedSize(referenceId), storedSize(viewId))
    }
  }

  @Test
  fun aLayoutTheMeasurementWouldNotBuildStoresNothing() {
    val text = SpannableStringBuilder(states.last())

    assertNull(MeasurementStore.storeLaidOut(viewId, layoutOf(text), 0, 0f, ""))

    // Stored, but without a width offered.
    MeasurementStore.store(viewId, text, paint)
    assertNull(MeasurementStore.storeLaidOut(viewId, layoutOf(text), 0, 0f, ""))

    measureAt(viewId)
    assertNull(MeasurementStore.storeLaidOut(viewId, layoutOf(text, WIDTH / 2), 0, 0f, ""))

    MeasurementStore.updateNumberOfLines(viewId, 2)
    assertNull(MeasurementStore.storeLaidOut(viewId, layoutOf(text), 0, 0f, ""))
  }

  private companion object {
    const val WIDTH = 300
    const val TRAILING_MARGIN_PX = 12f
  }
}
