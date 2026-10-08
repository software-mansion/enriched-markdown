package com.swmansion.enriched.markdown

import java.util.concurrent.PriorityBlockingQueue
import java.util.concurrent.atomic.AtomicLong
import kotlin.concurrent.thread

internal object MarkdownRenderDispatcher {
  private const val POOL_SIZE = 3

  private val sequence = AtomicLong(0)

  private data class RenderJob(
    val priority: Int,
    val order: Long,
    val isCancelled: () -> Boolean,
    val task: () -> Unit,
  ) : Comparable<RenderJob> {
    override fun compareTo(other: RenderJob): Int {
      val byPriority = other.priority.compareTo(priority)
      if (byPriority != 0) {
        return byPriority
      }
      return order.compareTo(other.order)
    }
  }

  private class RenderWorker(
    name: String,
  ) {
    private val queue = PriorityBlockingQueue<RenderJob>()

    init {
      thread(name = name, isDaemon = true) {
        while (!Thread.interrupted()) {
          try {
            val job = queue.take()
            if (!job.isCancelled()) {
              job.task()
            }
          } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            break
          }
        }
      }
    }

    fun submit(job: RenderJob) {
      queue.offer(job)
    }
  }

  private val workers = Array(POOL_SIZE) { index -> RenderWorker("enriched-markdown-render-$index") }

  fun submit(
    owner: Any,
    priority: Int,
    isCancelled: () -> Boolean,
    task: () -> Unit,
  ) {
    val workerIndex = (System.identityHashCode(owner) and Int.MAX_VALUE) % POOL_SIZE
    workers[workerIndex].submit(
      RenderJob(
        priority = priority,
        order = sequence.incrementAndGet(),
        isCancelled = isCancelled,
        task = task,
      ),
    )
  }
}
