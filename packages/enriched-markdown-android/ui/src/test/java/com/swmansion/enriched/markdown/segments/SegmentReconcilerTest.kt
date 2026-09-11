package com.swmansion.enriched.markdown.segments

import android.content.Context
import android.text.SpannableString
import android.view.View
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import org.junit.Assert.assertEquals
import org.junit.Assert.assertSame
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.annotation.Config

@RunWith(AndroidJUnit4::class)
@Config(sdk = [28, 35])
class SegmentReconcilerTest {
  private val context: Context = ApplicationProvider.getApplicationContext()

  private fun textSegment(signature: Long): RenderedSegment.Text =
    RenderedSegment.Text(
      styledText = SpannableString(""),
      imageSpans = emptyList(),
      needsJustify = false,
      lastElementMarginBottom = 0f,
      signature = signature,
    )

  private fun reconcile(
    currentViews: List<View>,
    currentSignatures: List<Long>,
    renderedSegments: List<RenderedSegment>,
    reset: Boolean = false,
    updateView: (View, RenderedSegment) -> Unit = { _, _ -> },
  ): ReconciliationResult =
    SegmentReconciler.reconcile(
      currentViews = currentViews,
      currentSignatures = currentSignatures,
      renderedSegments = renderedSegments,
      reset = reset,
      matchesKind = { _, _ -> true },
      createView = { View(context) },
      updateView = updateView,
    )

  @Test
  fun reuseByExactSignature() {
    val viewA = View(context)
    val viewB = View(context)
    val segmentA = textSegment(1L)
    val segmentB = textSegment(2L)

    val result =
      reconcile(
        currentViews = listOf(viewA, viewB),
        currentSignatures = listOf(1L, 2L),
        renderedSegments = listOf(segmentA, segmentB),
        updateView = { _, _ -> throw AssertionError("updateView must not be called") },
      )

    assertEquals(listOf(viewA, viewB), result.views)
    assertEquals(listOf(1L, 2L), result.signatures)
    assertTrue(result.viewsToRemove.isEmpty())
    assertTrue(result.viewsToAttach.isEmpty())
  }

  @Test
  fun signatureBasedFallbackWhenSegmentsSwapPositions() {
    val viewA = View(context)
    val viewB = View(context)
    val segmentA = textSegment(1L)
    val segmentB = textSegment(2L)

    val result =
      reconcile(
        currentViews = listOf(viewA, viewB),
        currentSignatures = listOf(1L, 2L),
        renderedSegments = listOf(segmentB, segmentA),
      )

    assertSame(viewB, result.views[0])
    assertSame(viewA, result.views[1])
    assertEquals(listOf(2L, 1L), result.signatures)
    assertTrue(result.viewsToRemove.isEmpty())
    assertTrue(result.viewsToAttach.isEmpty())
  }

  @Test
  fun sameKindPositionalUpdateWhenSignatureChangesAndDoesNotReappear() {
    val viewA = View(context)
    val changedSegment = textSegment(2L)
    var updatedView: View? = null
    var updatedSegment: RenderedSegment? = null

    val result =
      reconcile(
        currentViews = listOf(viewA),
        currentSignatures = listOf(1L),
        renderedSegments = listOf(changedSegment),
        updateView = { view, segment ->
          updatedView = view
          updatedSegment = segment
        },
      )

    assertSame(viewA, updatedView)
    assertSame(changedSegment, updatedSegment)
    assertSame(viewA, result.views[0])
    assertEquals(listOf(2L), result.signatures)
    assertTrue(result.viewsToRemove.isEmpty())
    assertTrue(result.viewsToAttach.isEmpty())
  }

  @Test
  fun removalWhenNewListIsShorter() {
    val viewA = View(context)
    val viewB = View(context)
    val segmentA = textSegment(1L)

    val result =
      reconcile(
        currentViews = listOf(viewA, viewB),
        currentSignatures = listOf(1L, 2L),
        renderedSegments = listOf(segmentA),
      )

    assertEquals(listOf(viewA), result.views)
    assertEquals(listOf(viewB), result.viewsToRemove)
    assertTrue(result.viewsToAttach.isEmpty())
  }

  @Test
  fun resetRemovesEveryCurrentViewAndCreatesFresh() {
    val viewA = View(context)
    val viewB = View(context)
    val segmentA = textSegment(1L)
    val segmentB = textSegment(2L)

    val result =
      reconcile(
        currentViews = listOf(viewA, viewB),
        currentSignatures = listOf(1L, 2L),
        renderedSegments = listOf(segmentA, segmentB),
        reset = true,
        updateView = { _, _ -> throw AssertionError("updateView must not be called on reset") },
      )

    assertEquals(listOf(viewA, viewB), result.viewsToRemove)
    assertEquals(2, result.viewsToAttach.size)
    assertTrue(result.views.none { it === viewA || it === viewB })
    assertEquals(listOf(1L, 2L), result.signatures)
  }
}
