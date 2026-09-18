package com.swmansion.enriched.markdown.utils.text

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import android.util.Log
import okhttp3.Cache
import okhttp3.Call
import okhttp3.Callback
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import java.io.File
import java.io.FileInputStream
import java.io.IOException
import java.util.concurrent.TimeUnit

object ImageDownloader {
  private const val TAG = "ImageDownloader"
  private const val DISK_CACHE_SIZE = 100L * 1024 * 1024
  private const val TIMEOUT = 15L

  private val mainHandler = Handler(Looper.getMainLooper())

  @Volatile
  private var client: OkHttpClient? = null
  private var maxTargetWidth: Int = 0

  private val inFlight = HashMap<String, MutableList<(DecodedImage?) -> Unit>>()

  private fun getClient(context: Context): OkHttpClient =
    client ?: synchronized(this) {
      client ?: buildClient(context).also {
        client = it
        maxTargetWidth = context.applicationContext.resources.displayMetrics.widthPixels
      }
    }

  private fun buildClient(context: Context): OkHttpClient {
    val cacheDir = File(context.applicationContext.cacheDir, "enrm_image_cache")
    return OkHttpClient
      .Builder()
      .cache(Cache(cacheDir, DISK_CACHE_SIZE))
      .connectTimeout(TIMEOUT, TimeUnit.SECONDS)
      .readTimeout(TIMEOUT, TimeUnit.SECONDS)
      .build()
  }

  fun download(
    context: Context,
    url: String,
    headers: Map<String, String> = emptyMap(),
    callback: (DecodedImage?) -> Unit,
  ) {
    val requestKey = ImageCache.requestKey(url, headers)

    ImageCache.getOriginalImage(requestKey)?.let {
      callback(it)
      return
    }

    synchronized(inFlight) {
      val existing = inFlight[requestKey]
      if (existing != null) {
        existing.add(callback)
        return
      }
      inFlight[requestKey] = mutableListOf(callback)
    }

    val request =
      Request
        .Builder()
        .url(url)
        .apply { headers.forEach { (name, value) -> addHeader(name, value) } }
        .build()
    getClient(context).newCall(request).enqueue(
      object : Callback {
        override fun onResponse(
          call: Call,
          response: Response,
        ) {
          val decoded =
            response.use {
              if (!it.isSuccessful) {
                Log.w(TAG, "Image request failed with HTTP ${it.code}: $url")
                return@use null
              }
              try {
                val bytes = it.body?.bytes() ?: return@use null
                decodeDownsampled(bytes, maxTargetWidth)
              } catch (_: OutOfMemoryError) {
                Log.e(TAG, "OOM decoding image: $url")
                null
              } catch (e: Exception) {
                Log.e(TAG, "Failed to decode image: $url", e)
                null
              }
            }

          decoded?.let { ImageCache.putOriginal(requestKey, it) }
          dispatchCallbacks(requestKey, decoded)
        }

        override fun onFailure(
          call: Call,
          e: IOException,
        ) {
          Log.e(TAG, "Failed to download image: $url", e)
          dispatchCallbacks(requestKey, null)
        }
      },
    )
  }

  // BitmapFactory decodes a GIF to its first frame, which serves as the poster.
  private fun decodeDownsampled(
    bytes: ByteArray,
    targetWidth: Int,
  ): DecodedImage? {
    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
    val bitmap =
      decodeWithSampleSize(opts, targetWidth) {
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, it)
      } ?: return null
    return DecodedImage(bitmap, AnimatedImages.animatedBytesOrNull(bytes))
  }

  fun decodeBytesDownsampled(
    context: Context,
    bytes: ByteArray,
  ): DecodedImage? = decodeDownsampled(bytes, context.resources.displayMetrics.widthPixels)

  fun decodeFileDownsampled(
    context: Context,
    path: String,
  ): DecodedImage? {
    if (AnimatedImages.isSupported && fileHasGifHeader(path)) {
      return decodeBytesDownsampled(context, File(path).readBytes())
    }
    val targetWidth = context.resources.displayMetrics.widthPixels
    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, opts)
    val bitmap =
      decodeWithSampleSize(opts, targetWidth) {
        BitmapFactory.decodeFile(path, it)
      } ?: return null
    return DecodedImage(bitmap)
  }

  private fun fileHasGifHeader(path: String): Boolean =
    try {
      FileInputStream(path).use { stream ->
        val header = ByteArray(6)
        var read = 0
        while (read < header.size) {
          val n = stream.read(header, read, header.size - read)
          if (n < 0) break
          read += n
        }
        read == header.size && AnimatedImages.isGifHeader(header)
      }
    } catch (_: IOException) {
      false
    }

  private inline fun decodeWithSampleSize(
    opts: BitmapFactory.Options,
    targetWidth: Int,
    decode: (BitmapFactory.Options) -> Bitmap?,
  ): Bitmap? {
    if (opts.outWidth <= 0 || opts.outHeight <= 0) return null
    opts.inSampleSize = calculateInSampleSize(opts.outWidth, targetWidth)
    opts.inJustDecodeBounds = false
    return decode(opts)
  }

  private fun calculateInSampleSize(
    srcWidth: Int,
    reqWidth: Int,
  ): Int {
    if (srcWidth in 0..reqWidth) return 1
    return Integer.highestOneBit(srcWidth / reqWidth)
  }

  private fun dispatchCallbacks(
    requestKey: String,
    image: DecodedImage?,
  ) {
    val callbacks = synchronized(inFlight) { inFlight.remove(requestKey) } ?: return
    mainHandler.post {
      callbacks.forEach { it(image) }
    }
  }
}
