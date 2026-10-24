package com.swmansion.enriched.markdown.math

import android.util.Log
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Runs [block], turning any RaTeX failure into [onFailure] and a null result.
 *
 * RaTeX is backed by a native library that ships for arm64-v8a, armeabi-v7a and x86_64 only, so on
 * any other ABI - a 32-bit x86 emulator, most often - the first call into it fails outright. That
 * failure arrives as a [LinkageError] ([UnsatisfiedLinkError], [ExceptionInInitializerError],
 * [NoClassDefFoundError]), which is an `Error` rather than an `Exception`: catching `Exception`
 * alone lets it escape and take the render thread or the view down with it. The plugin contract
 * says a plugin degrades to plain rendering instead of throwing, so every entry into RaTeX goes
 * through here and every caller has a source-echoing fallback.
 *
 * Nothing broader is caught. A VM error such as `OutOfMemoryError` says the process is in trouble,
 * which drawing the source instead would only hide.
 */
internal inline fun <T> runRaTeX(
  onFailure: (Throwable) -> Unit = {},
  block: () -> T,
): T? =
  try {
    block()
  } catch (e: Exception) {
    onFailure(e)
    null
  } catch (e: LinkageError) {
    warnNativeLibraryUnavailable(e)
    onFailure(e)
    null
  }

private val nativeLibraryWarningLogged = AtomicBoolean(false)

/**
 * Logs a [LinkageError] from [runRaTeX] once per process. Whether the native library loads is
 * decided by the device's ABI, so after the first failure every equation fails the same way, and
 * logging each one would only repeat it. A malformed expression is not logged at all: it is the
 * content's problem rather than the app's, and plugins report it through `LatexError`.
 */
internal fun warnNativeLibraryUnavailable(error: LinkageError) {
  if (nativeLibraryWarningLogged.compareAndSet(false, true)) {
    Log.w("RaTeX", "RaTeX native library is unavailable on this device; math renders as its source.", error)
  }
}
