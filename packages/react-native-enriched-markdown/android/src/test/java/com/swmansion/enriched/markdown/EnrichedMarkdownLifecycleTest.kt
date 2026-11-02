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
    val postToMain =
      EnrichedMarkdown::class.java.getDeclaredMethod(
        "postToMain",
        Long::class.javaPrimitiveType,
        Function0::class.java,
      )
    postToMain.isAccessible = true
    postToMain.invoke(view, 0L, action)
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
