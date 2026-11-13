package com.swmansion.enriched.markdown.utils

import com.swmansion.enriched.markdown.utils.common.RenderCoordinator
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
class RenderCoordinatorTest {
  // The executor and the main thread, run by hand.
  private val queued = ArrayDeque<Runnable>()
  private val posted = ArrayDeque<Runnable>()
  private val coordinator = RenderCoordinator({ queued.addLast(it) }, { posted.addLast(it) })
  private val renders = mutableListOf<String>()
  private val applies = mutableListOf<String>()

  private fun revision(
    name: String,
    whileRendering: () -> Unit = {},
  ): () -> Runnable? =
    {
      renders += name
      whileRendering()
      Runnable { applies += name }
    }

  private fun runAll() {
    while (queued.isNotEmpty()) queued.removeFirst().run()
    while (posted.isNotEmpty()) posted.removeFirst().run()
  }

  @Test
  fun burstRendersOnlyTheNewestAndTheRenderInFlightStillShows() {
    coordinator.schedule(
      revision("in flight") {
        coordinator.schedule(revision("revision 1"))
        coordinator.schedule(revision("revision 2"))
      },
    )
    runAll()

    assertEquals(listOf("in flight", "revision 2"), renders)
    assertEquals(listOf("in flight", "revision 2"), applies)
  }

  @Test
  fun invalidateDropsTheWaitingRenderAndTheResultInFlight() {
    coordinator.schedule(
      revision("in flight") {
        coordinator.schedule(revision("waiting"))
        coordinator.invalidate()
      },
    )
    runAll()
    coordinator.schedule(revision("next"))
    runAll()

    assertEquals(listOf("in flight", "next"), renders)
    assertEquals(listOf("next"), applies)
  }

  @Test
  fun aRenderWithNothingToApplyPostsNothing() {
    coordinator.schedule { null }
    while (queued.isNotEmpty()) queued.removeFirst().run()

    assertEquals(0, posted.size)
  }
}
