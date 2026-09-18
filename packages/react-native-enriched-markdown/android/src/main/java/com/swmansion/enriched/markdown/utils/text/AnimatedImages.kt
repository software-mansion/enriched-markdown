package com.swmansion.enriched.markdown.utils.text

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.ImageDecoder
import android.graphics.drawable.AnimatedImageDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.util.Log
import android.util.LruCache
import android.widget.TextView
import androidx.annotation.RequiresApi
import java.nio.ByteBuffer
import java.util.WeakHashMap

/**
 * Animated GIF support via [AnimatedImageDrawable] (API 28+); older devices
 * show the first frame through the regular bitmap path.
 *
 * Drawables are owned per host view and keyed by request, because every render
 * creates fresh spans and a streaming update would otherwise decode the GIF
 * again and restart it on each token.
 */
object AnimatedImages {
  private const val TAG = "AnimatedImages"
  private const val GIF_HEADER_LENGTH = 6
  private const val MAX_REMEMBERED_STILL_KEYS = 256
  private const val MAX_DRAWABLES_PER_VIEW = 8

  val isSupported: Boolean
    get() = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P

  fun isGifHeader(header: ByteArray): Boolean =
    header.size >= GIF_HEADER_LENGTH &&
      header[0] == 'G'.code.toByte() &&
      header[1] == 'I'.code.toByte() &&
      header[2] == 'F'.code.toByte() &&
      header[3] == '8'.code.toByte() &&
      (header[4] == '7'.code.toByte() || header[4] == '9'.code.toByte()) &&
      header[5] == 'a'.code.toByte()

  /** `bytes` when they are a GIF the device can animate, else null. */
  fun animatedBytesOrNull(bytes: ByteArray): ByteArray? = if (isSupported && isGifHeader(bytes)) bytes else null

  /** Honours the system "remove animations" setting (animator duration scale 0). */
  fun animationsEnabled(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.O || ValueAnimator.areAnimatorsEnabled()

  // GIFs that turned out to be single-frame; skips the ImageDecoder pass for them.
  private val stillGifKeys = LruCache<String, Boolean>(MAX_REMEMBERED_STILL_KEYS)

  // view -> request key -> drawable; weak on the view so its decoders die with
  // it, and bounded per view so a long-lived transcript can't pile them up.
  private val drawablesByView = WeakHashMap<TextView, LruCache<String, AnimatedImageDrawable>>()

  /**
   * The looping drawable for `requestKey` on `view`, decoded on first use and
   * reused afterwards. Null for single-frame or undecodable GIFs. Main thread only.
   */
  @RequiresApi(Build.VERSION_CODES.P)
  fun drawableFor(
    view: TextView,
    requestKey: String,
    bytes: ByteArray,
  ): AnimatedImageDrawable? {
    if (stillGifKeys.get(requestKey) != null) return null
    val perView = drawablesByView.getOrPut(view) { LruCache(MAX_DRAWABLES_PER_VIEW) }
    perView.get(requestKey)?.let { return it }
    // A decode error is not memoised: the next render may succeed.
    val decoded = createDrawable(view.context, bytes) ?: return null
    val animated = decoded as? AnimatedImageDrawable
    if (animated == null) {
      // A single-frame GIF decodes to a plain BitmapDrawable.
      stillGifKeys.put(requestKey, true)
      return null
    }
    animated.repeatCount = AnimatedImageDrawable.REPEAT_INFINITE
    perView.put(requestKey, animated)
    return animated
  }

  /** The decoded drawable (animated or not), or null when decoding failed. */
  @RequiresApi(Build.VERSION_CODES.P)
  private fun createDrawable(
    context: Context,
    bytes: ByteArray,
  ): Drawable? =
    try {
      val targetWidth = context.resources.displayMetrics.widthPixels
      val source = ImageDecoder.createSource(ByteBuffer.wrap(bytes))
      ImageDecoder.decodeDrawable(source) { decoder, info, _ ->
        val sampleSize = sampleSizeFor(info.size.width, targetWidth)
        if (sampleSize > 1) decoder.setTargetSampleSize(sampleSize)
      }
    } catch (_: OutOfMemoryError) {
      Log.e(TAG, "OOM decoding animated image")
      null
    } catch (e: Exception) {
      Log.w(TAG, "Failed to decode animated image", e)
      null
    }

  private fun sampleSizeFor(
    srcWidth: Int,
    reqWidth: Int,
  ): Int {
    if (reqWidth <= 0 || srcWidth <= reqWidth) return 1
    return Integer.highestOneBit(srcWidth / reqWidth).coerceAtLeast(1)
  }
}
