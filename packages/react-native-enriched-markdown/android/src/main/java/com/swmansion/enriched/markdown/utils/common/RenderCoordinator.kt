package com.swmansion.enriched.markdown.utils.common

import android.util.Log
import java.util.concurrent.Executor

/**
 * Runs a host's renders on [executor], one at a time, and hands each result to [post]
 * for the main thread (the iOS host's ENRMAsyncRenderCoordinator).
 *
 * A render scheduled while another runs replaces any still waiting, so a burst renders
 * only the newest. A finished render applies unless a newer one already did: a newer
 * render still waiting doesn't hold it back, so while updates arrive faster than a
 * render takes, each finished render shows instead of none.
 */
class RenderCoordinator(
  private val executor: Executor,
  private val post: (Runnable) -> Unit,
) {
  private val lock = Any()
  private var currentRenderId = 0L
  private var pending: Pair<Long, () -> Runnable?>? = null
  private var workerActive = false

  // Renders run in order, so IDs only grow: older than the applied one means outdated.
  private var lastAppliedRenderId = 0L
  private var firstApplicableRenderId = 0L

  /** [render] runs on the executor and returns what to run on the main thread, or null for nothing. */
  fun schedule(render: () -> Runnable?) {
    synchronized(lock) {
      pending = ++currentRenderId to render
      if (workerActive) return
      workerActive = true
    }
    executor.execute { drain() }
  }

  /** Drops the waiting render and the result of the one in flight (a synchronous render, a reset). */
  fun invalidate() {
    synchronized(lock) {
      firstApplicableRenderId = ++currentRenderId
      pending = null
    }
  }

  private fun drain() {
    while (true) {
      val (renderId, render) =
        synchronized(lock) {
          val next = pending
          pending = null
          if (next == null) workerActive = false
          next
        } ?: return
      val apply =
        try {
          render()
        } catch (e: Exception) {
          Log.e(TAG, "Render failed", e)
          null
        } ?: continue
      post(
        Runnable {
          val applies =
            synchronized(lock) {
              (renderId >= firstApplicableRenderId && renderId > lastAppliedRenderId).also {
                if (it) lastAppliedRenderId = renderId
              }
            }
          if (applies) apply.run()
        },
      )
    }
  }

  companion object {
    private const val TAG = "RenderCoordinator"
  }
}
