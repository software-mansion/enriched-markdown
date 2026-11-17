package com.swmansion.enriched.markdown.utils.common

import android.util.Log
import java.util.concurrent.Executor

/**
 * Runs renders on [executor] one at a time; a newly scheduled one replaces any still waiting.
 * A finished render applies even when a newer one waits: otherwise nothing would show while
 * updates arrive faster than a render takes.
 */
class RenderCoordinator(
  private val executor: Executor,
  private val post: (Runnable) -> Unit,
) {
  private val lock = Any()
  private var currentRenderId = 0L
  private var pending: Pair<Long, () -> Runnable?>? = null
  private var workerActive = false
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
    try {
      drainPending()
    } catch (e: Throwable) {
      // An Error escaping a render must not leave the worker marked active forever.
      val resume = synchronized(lock) { (pending != null).also { workerActive = it } }
      if (resume) executor.execute { drain() }
      throw e
    }
  }

  private fun drainPending() {
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
          val applies = synchronized(lock) { renderId >= firstApplicableRenderId }
          if (applies) apply.run()
        },
      )
    }
  }

  companion object {
    private const val TAG = "RenderCoordinator"
  }
}
