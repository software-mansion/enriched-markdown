package com.swmansion.enriched.markdown.spans

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.text.Spannable
import android.text.Spanned
import android.text.style.LeadingMarginSpan
import android.util.Log
import android.widget.TextView
import androidx.core.graphics.createBitmap
import androidx.core.graphics.drawable.toDrawable
import androidx.core.graphics.withClip
import androidx.core.graphics.withSave
import com.swmansion.enriched.markdown.styles.StyleConfig
import com.swmansion.enriched.markdown.utils.text.ImageCache
import com.swmansion.enriched.markdown.utils.text.ImageDownloader
import com.swmansion.enriched.markdown.utils.text.LocalImageLoader
import java.lang.ref.WeakReference
import java.util.concurrent.Executors
import android.text.style.ImageSpan as AndroidImageSpan
import android.text.style.LineHeightSpan as AndroidLineHeightSpan

class ImageSpan(
  private val context: Context,
  val imageUrl: String,
  styleConfig: StyleConfig,
  val isInline: Boolean = false,
  val altText: String = "",
  private val requestHeaders: Map<String, String> = emptyMap(),
) : AndroidImageSpan(
    Color.TRANSPARENT.toDrawable(),
    imageUrl,
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ALIGN_CENTER else ALIGN_BASELINE,
  ),
  AndroidLineHeightSpan {
  private var loadedDrawable: Drawable? = null
  private val height: Int = if (isInline) styleConfig.inlineImageStyle.size.toInt() else styleConfig.imageStyle.height.toInt()
  private val borderRadiusPx: Int = (styleConfig.imageStyle.borderRadius * context.resources.displayMetrics.density).toInt()
  private val requestKey: String = ImageCache.requestKey(imageUrl, requestHeaders)

  private var cachedWidth: Int = 0
  private var viewRef: WeakReference<TextView>? = null
  private var sourceDrawable: Drawable? = null

  init {
    loadImage()
  }

  private fun loadImage() {
    val scheme = Uri.parse(imageUrl).scheme?.lowercase()
    if (scheme == "http" || scheme == "https") {
      ImageDownloader.download(context, imageUrl, requestHeaders) { bitmap ->
        if (bitmap != null) {
          sourceDrawable = bitmap.toDrawable(context.resources)
          wrapAndAssignDrawable()
        }
      }
    } else {
      val cached = ImageCache.getOriginal(imageUrl)
      val bitmap = cached ?: LocalImageLoader.load(context, imageUrl)
      if (bitmap != null) {
        if (cached == null) ImageCache.putOriginal(imageUrl, bitmap)
        sourceDrawable = bitmap.toDrawable(context.resources)
        wrapAndAssignDrawable()
      }
    }
  }

  private fun wrapAndAssignDrawable() {
    val base = sourceDrawable ?: return
    val targetWidth =
      if (isInline) {
        height
      } else {
        val available = viewRef?.get()?.let { getAvailableWidth(it) } ?: cachedWidth
        available.coerceAtLeast(0)
      }

    val cachedBitmap = ImageCache.getProcessed(requestKey, targetWidth, height, borderRadiusPx)
    if (cachedBitmap != null) {
      loadedDrawable =
        cachedBitmap.toDrawable(context.resources).apply {
          setBounds(0, 0, targetWidth, height)
        }
    } else {
      loadedDrawable =
        ScaledImageDrawable(
          imageDrawable = base,
          targetWidth = targetWidth,
          targetHeight = height,
          borderRadius = borderRadiusPx,
          isBlockImage = !isInline,
          cacheKey = CacheKey(requestKey, targetWidth, height, borderRadiusPx),
        )
    }
    requestReflow()
  }

  private fun requestReflow() {
    val view = viewRef?.get() ?: return
    val text = view.text
    if (text is Spannable) {
      val start = text.getSpanStart(this)
      val end = text.getSpanEnd(this)
      if (start != -1 && end != -1) {
        text.setSpan(this, start, end, Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
      }
    } else {
      view.invalidate()
      view.requestLayout()
    }
  }

  fun registerTextView(view: TextView) {
    viewRef = WeakReference(view)
    if (!isInline) {
      val availableWidth = getAvailableWidth(view)
      if (availableWidth > 0) {
        updateWidthAndRecreate(availableWidth)
      }
      view.post {
        val postWidth = getAvailableWidth(view)
        if (postWidth != cachedWidth) updateWidthAndRecreate(postWidth)
      }
    }
  }

  private fun updateWidthAndRecreate(newWidth: Int) {
    if (newWidth <= 0 || cachedWidth == newWidth) return
    cachedWidth = newWidth
    if (sourceDrawable != null) {
      wrapAndAssignDrawable()
    }
  }

  private fun getAvailableWidth(view: TextView): Int {
    val baseWidth = (view.layout?.width ?: view.width).coerceAtLeast(0)
    val text = view.text as? Spanned ?: return baseWidth
    val start = text.getSpanStart(this).takeIf { it >= 0 } ?: return baseWidth
    val end = text.getSpanEnd(this).coerceAtLeast(start)
    // Subtract leading margins (list bullet/indent, blockquote bar) that consume
    // horizontal space on the image's line. first=true is correct because a block
    // image sits on its own line — the "first line" from the layout's perspective.
    val totalMargin =
      text
        .getSpans(start, end, LeadingMarginSpan::class.java)
        .sumOf { it.getLeadingMargin(true) }
    return (baseWidth - totalMargin).coerceAtLeast(0)
  }

  override fun getDrawable(): Drawable {
    val drawable = loadedDrawable ?: transparentDrawable
    if (drawable !is ScaledImageDrawable) {
      val drawableWidth = if (isInline) height else cachedWidth.takeIf { it > 0 } ?: drawable.intrinsicWidth
      drawable.setBounds(0, 0, drawableWidth.coerceAtLeast(0), height.coerceAtLeast(0))
    }
    return drawable
  }

  override fun getSize(
    paint: Paint,
    text: CharSequence?,
    start: Int,
    end: Int,
    fm: Paint.FontMetricsInt?,
  ): Int = getDrawable().bounds.right

  override fun chooseHeight(
    text: CharSequence?,
    start: Int,
    end: Int,
    spanstartv: Int,
    lineHeight: Int,
    fm: Paint.FontMetricsInt?,
  ) {
    if (fm == null || isInline) return
    val currentLineHeight = fm.descent - fm.ascent
    if (height > currentLineHeight) {
      val extraHeight = height - currentLineHeight
      fm.descent += extraHeight
      fm.bottom += extraHeight
    }
  }

  override fun draw(
    canvas: Canvas,
    text: CharSequence?,
    start: Int,
    end: Int,
    x: Float,
    top: Int,
    y: Int,
    bottom: Int,
    paint: Paint,
  ) {
    val drawable = getDrawable()
    canvas.withSave {
      if (isInline) {
        val imageHeight = drawable.bounds.height()
        translate(x, (y - imageHeight + (imageHeight * 0.1f)))
      } else {
        translate(x, top.toFloat())
      }
      drawable.draw(this)
    }
  }

  private data class CacheKey(
    val url: String,
    val width: Int,
    val height: Int,
    val borderRadius: Int,
  )

  private class ScaledImageDrawable(
    private val imageDrawable: Drawable,
    private val targetWidth: Int,
    private val targetHeight: Int,
    private val borderRadius: Int,
    isBlockImage: Boolean,
    private val cacheKey: CacheKey? = null,
  ) : Drawable() {
    private val clipPath: Path?
    private var hasCached = false

    init {
      setBounds(0, 0, targetWidth, targetHeight)
      val intrinsicWidth = imageDrawable.intrinsicWidth
      val intrinsicHeight = imageDrawable.intrinsicHeight

      val (scaledWidth, scaledHeight) =
        if (intrinsicWidth > 0 && intrinsicHeight > 0) {
          if (isBlockImage) {
            val scale = targetWidth.toFloat() / intrinsicWidth
            targetWidth to (intrinsicHeight * scale).toInt()
          } else {
            val scale = minOf(targetWidth.toFloat() / intrinsicWidth, targetHeight.toFloat() / intrinsicHeight)
            (intrinsicWidth * scale).toInt() to (intrinsicHeight * scale).toInt()
          }
        } else {
          targetWidth to targetHeight
        }

      val left = (targetWidth - scaledWidth) / 2
      val top = (targetHeight - scaledHeight) / 2
      imageDrawable.setBounds(left, top, left + scaledWidth, top + scaledHeight)

      clipPath =
        if (borderRadius > 0) {
          val clipLeft = maxOf(0, left).toFloat()
          val clipTop = maxOf(0, top).toFloat()
          val clipRight = minOf(targetWidth, left + scaledWidth).toFloat()
          val clipBottom = minOf(targetHeight, top + scaledHeight).toFloat()
          Path().apply {
            addRoundRect(
              clipLeft,
              clipTop,
              clipRight,
              clipBottom,
              borderRadius.toFloat(),
              borderRadius.toFloat(),
              Path.Direction.CW,
            )
          }
        } else {
          null
        }
    }

    override fun draw(canvas: Canvas) {
      if (clipPath != null) {
        canvas.withSave {
          clipPath(clipPath)
          imageDrawable.draw(canvas)
        }
      } else {
        imageDrawable.draw(canvas)
      }
      scheduleCacheBitmap()
    }

    private fun scheduleCacheBitmap() {
      if (hasCached || cacheKey == null || targetWidth <= 0 || targetHeight <= 0) return
      hasCached = true
      val cachedKey = cacheKey
      val width = targetWidth
      val height = targetHeight
      val path = clipPath
      val source = imageDrawable
      cacheExecutor.execute {
        try {
          val bitmap = createBitmap(width, height)
          val offscreen = Canvas(bitmap)
          if (path != null) {
            offscreen.withClip(path) { source.draw(this) }
          } else {
            source.draw(offscreen)
          }
          ImageCache.putProcessed(cachedKey.url, cachedKey.width, cachedKey.height, cachedKey.borderRadius, bitmap)
        } catch (_: OutOfMemoryError) {
          Log.e("ScaledImageDrawable", "OOM caching bitmap ${width}x$height")
        }
      }
    }

    override fun setAlpha(alpha: Int) {
      imageDrawable.alpha = alpha
    }

    override fun setColorFilter(colorFilter: android.graphics.ColorFilter?) {
      imageDrawable.colorFilter = colorFilter
    }

    @Suppress("DEPRECATION")
    @Deprecated("Deprecated in Java")
    override fun getOpacity(): Int = imageDrawable.opacity

    override fun getIntrinsicWidth(): Int = targetWidth

    override fun getIntrinsicHeight(): Int = targetHeight
  }

  companion object {
    private val transparentDrawable by lazy { Color.TRANSPARENT.toDrawable() }
    private val cacheExecutor = Executors.newSingleThreadExecutor()
  }
}
