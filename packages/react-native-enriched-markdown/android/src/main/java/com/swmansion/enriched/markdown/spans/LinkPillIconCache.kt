package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import com.swmansion.enriched.markdown.utils.text.ImageCache
import com.swmansion.enriched.markdown.utils.text.LocalImageLoader
import java.io.File
import java.security.MessageDigest

/** Original-color thumbnails, using the library's local resolver and bounded cache. */
internal object LinkPillIconCache {
  private val images = ImageCache.bitmapLruCache(8 * 1024 * 1024, 64)

  @Synchronized
  fun load(
    context: Context,
    iconUri: String,
  ): Bitmap? =
    runCatching {
      if (iconUri.isEmpty()) return@runCatching null
      val uri = Uri.parse(iconUri)
      if (uri.scheme?.lowercase() in listOf("http", "https")) return@runCatching null
      val file =
        if (uri.scheme == "file" || (uri.scheme == null && iconUri.startsWith('/'))) {
          File(uri.path ?: iconUri).canonicalFile.takeIf { it.isFile }
        } else {
          null
        }
      // Data URIs can be large; retain only their digest in cache keys.
      val sourceKey = MessageDigest.getInstance("SHA-256").digest(iconUri.toByteArray()).joinToString("") { "%02x".format(it) }
      val key = "${context.packageName}|$sourceKey|${file?.path}|${file?.lastModified()}|${file?.length()}"
      images.get(key)?.let { return@runCatching it }
      LocalImageLoader.load(context, iconUri, maxDimension = 512)?.also { images.put(key, it) }
    }.getOrNull()
}
