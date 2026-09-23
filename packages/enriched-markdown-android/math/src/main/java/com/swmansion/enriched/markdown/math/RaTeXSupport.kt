package com.swmansion.enriched.markdown.math

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
    onFailure(e)
    null
  }
