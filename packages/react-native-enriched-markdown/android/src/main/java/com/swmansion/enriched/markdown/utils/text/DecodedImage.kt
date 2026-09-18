package com.swmansion.enriched.markdown.utils.text

import android.graphics.Bitmap

/**
 * The still bitmap (for a GIF, its first frame) plus the encoded bytes when the
 * source is a GIF the platform can animate. Cached together so an eviction never
 * strands a poster frame without its animation.
 */
class DecodedImage(
  val bitmap: Bitmap,
  val animatedBytes: ByteArray? = null,
)
