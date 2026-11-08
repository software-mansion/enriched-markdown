package com.swmansion.enriched.markdown

import android.os.Looper
import com.facebook.react.bridge.JavaOnlyMap
import com.facebook.react.uimanager.StateWrapper
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.annotation.LooperMode
import java.lang.reflect.Proxy
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [28])
@LooperMode(LooperMode.Mode.PAUSED)
class EnrichedMarkdownLifecycleTest {
  private fun newView() = EnrichedMarkdown(RuntimeEnvironment.getApplication())

  // Posts through the view's own main Handler the way a finished render does,
  // without needing the native parser, which is not loaded on the JVM.
  private fun postResult(
    view: EnrichedMarkdown,
    action: () -> Unit,
  ) {
    val postToMain = EnrichedMarkdown::class.java.getDeclaredMethod("postToMain", Runnable::class.java)
    postToMain.isAccessible = true
    postToMain.invoke(view, Runnable { action() })
  }

  private fun idleMainLooper() = shadowOf(Looper.getMainLooper()).idle()

  @Test
  fun resultsApplyBeforeFirstAttachButNotAfterCleanup() {
    val view = newView()
    var applied = 0
    assertFalse(view.isAttachedToWindow)
    postResult(view) { applied++ }
    idleMainLooper()
    assertEquals(1, applied)

    postResult(view) { applied++ }
    view.cleanup()
    idleMainLooper()
    assertEquals(1, applied)
  }

  @Test
  fun resultPostedAfterCleanupIsNotApplied() {
    val view = newView()
    val releaseWorker = CountDownLatch(1)
    val posted = CountDownLatch(1)
    var applied = false
    // A render that ignores the interrupt from shutdownNow() and posts after cleanup.
    val worker =
      Thread {
        check(releaseWorker.await(5, TimeUnit.SECONDS))
        postResult(view) { applied = true }
        posted.countDown()
      }
    worker.start()
    view.cleanup()
    releaseWorker.countDown()
    assertTrue(posted.await(5, TimeUnit.SECONDS))
    worker.join()
    idleMainLooper()
    assertFalse(applied)
  }

  @Test
  fun cleanupReleasesStateWrapperAndIgnoresLateImageLayout() {
    val view = newView()
    view.layout(0, 0, 100, 100)
    view.onImageLayoutChanged()
    assertTrue(view.isLayoutRequested)
    view.layout(0, 0, 100, 100)
    assertFalse(view.isLayoutRequested)
    view.stateWrapper =
      Proxy.newProxyInstance(
        StateWrapper::class.java.classLoader,
        arrayOf(StateWrapper::class.java),
      ) { _, method, _ ->
        if (method.name == "toString") "TestStateWrapper" else error("Unexpected StateWrapper call: ${method.name}")
      } as StateWrapper

    view.cleanup()
    assertNull(view.stateWrapper)
    view.onImageLayoutChanged()
    assertFalse(view.isLayoutRequested)
  }

  // An older render can apply after a newer one was scheduled: it takes only the
  // flags set when it was scheduled, so the newer render still recreates its segments.
  @Test
  fun aRenderTakesOnlyTheFlagsSetWhenItWasScheduled() {
    val view = newView()
    val flagType = Class.forName("com.swmansion.enriched.markdown.EnrichedMarkdown\$DirtyFlag")
    val flag = { name: String -> flagType.enumConstants.first { (it as Enum<*>).name == name } }
    val flagsField = EnrichedMarkdown::class.java.getDeclaredField("dirtyFlags")
    flagsField.isAccessible = true

    @Suppress("UNCHECKED_CAST")
    val dirtyFlags = flagsField.get(view) as MutableSet<Any>
    dirtyFlags += flag("FORCE_HEIGHT")
    val scheduled = HashSet(dirtyFlags)
    dirtyFlags += flag("RECREATE_SEGMENTS")

    val apply =
      EnrichedMarkdown::class.java.declaredMethods.first { it.name == "applyRenderedSegments" }
    apply.isAccessible = true
    apply.invoke(view, emptyList<Any>(), false, scheduled, "")

    assertEquals(setOf(flag("RECREATE_SEGMENTS")), dirtyFlags.toSet())
  }

  @Test
  fun cleanupStopsRenderSubmissionAndPropBookkeeping() {
    val view = newView()
    view.id = 91327
    view.setMarkdownStyle(JavaOnlyMap())
    view.setMarkdownContent("Late update")
    view.cleanup()
    view.cleanup() // Idempotent.

    // Before the fix this submitted a render to the shut-down executor and threw
    // RejectedExecutionException.
    view.commitProps()

    val settings = MeasurementStore::class.java.getDeclaredField("fontScalingSettings")
    settings.isAccessible = true
    assertFalse((settings.get(MeasurementStore) as Map<*, *>).containsKey(view.id))
  }
}
