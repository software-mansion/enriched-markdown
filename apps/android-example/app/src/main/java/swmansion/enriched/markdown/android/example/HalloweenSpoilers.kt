package swmansion.enriched.markdown.android.example

import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import com.swmansion.enriched.markdown.spoiler.CustomSpoilerOverlay
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlayHost
import com.swmansion.enriched.markdown.spoiler.SpoilerSlice
import com.swmansion.enriched.markdown.spoiler.SpoilerSliceOverlay
import com.swmansion.enriched.markdown.styles.SpoilerStyle
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random

// Seven rooms of a haunted house, each a way of hiding the words, written for the Halloween
// screen. Each is a data class behind a slice overlay drawn on the text view's canvas. The
// overlays are text-aware: the hidden words show through as a faint ghost, and a reveal tears,
// burns or scatters what covers them, line by line for a wrapped spoiler.

private const val TWO_PI = (2 * PI).toFloat()
private const val WHITE = 0xFFFFFFFF.toInt()

/** The guest book's page, the color the overlays paint ahead of a reveal. */
const val GUEST_BOOK_PAGE = 0xFF171023.toInt()
private const val CREAM = 0xFFF1E4C8.toInt()

private fun easeInOut(p: Float): Float = if (p < 0.5f) 2 * p * p else 1 - (-2 * p + 2) * (-2 * p + 2) / 2

private fun easeOut(p: Float): Float = 1f - (1f - p) * (1f - p)

private fun easeIn(p: Float): Float = p * p

/**
 * Shared toolkit: the words as a bitmap and as a blurred glow, feathered sweep and radial masks,
 * soft ellipses, stars, per-slice randomness, and a reveal that runs line by line. Subclasses
 * draw the idle look in [drawIdle] and one frame of the reveal in [drawRevealing]; ahead of a
 * front they paint [page] over the words the library is fading in.
 */
internal abstract class HauntedSlice(
  host: SpoilerOverlayHost,
  protected val page: Int,
) : SpoilerSliceOverlay() {
  protected val dp = host.density
  protected lateinit var random: Random
  protected var width = 0f
  protected var height = 0f

  /** Gap between the starts of consecutive lines of one spoiler, as a fraction of its reveal. */
  protected open val lineStagger = 0.4f

  private var preparedFor = -1L
  private var textBitmap: Bitmap? = null
  private val glows = HashMap<Int, Pair<Bitmap, IntArray>>()
  private val gradients = HashMap<Int, RadialGradient>()
  private val bitmapPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
  private val maskPaint = Paint().apply { xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN) }
  protected val fill = Paint(Paint.ANTI_ALIAS_FLAG)
  protected val stroke =
    Paint(Paint.ANTI_ALIAS_FLAG).apply {
      style = Paint.Style.STROKE
      strokeCap = Paint.Cap.ROUND
      strokeJoin = Paint.Join.ROUND
    }
  protected val path = Path()
  private val rect = RectF()

  override val isAnimated get() = true

  protected abstract fun prepare(slice: SpoilerSlice)

  protected abstract fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  )

  protected abstract fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  )

  final override fun draw(
    canvas: Canvas,
    slice: SpoilerSlice,
  ) {
    ensurePrepared(slice)
    val saved = canvas.save()
    canvas.clipRect(0f, 0f, width, height)
    drawIdle(canvas, slice, slice.frameTimeMillis / 1000f)
    canvas.restoreToCount(saved)
  }

  final override fun drawReveal(
    canvas: Canvas,
    slice: SpoilerSlice,
    progress: Float,
  ) {
    ensurePrepared(slice)
    val span = 1f + lineStagger * (slice.count - 1)
    val local = (progress * span - slice.index * lineStagger).coerceIn(0f, 1f)
    val saved = canvas.save()
    canvas.clipRect(0f, 0f, width, height)
    when {
      // Waiting for the lines above: keep the idle look, and the words under it.
      local <= 0f -> {
        canvas.drawColor(page)
        drawIdle(canvas, slice, slice.frameTimeMillis / 1000f)
      }
      local < 1f -> drawRevealing(canvas, slice, slice.frameTimeMillis / 1000f, local)
    }
    canvas.restoreToCount(saved)
  }

  override fun onRemoved() {
    textBitmap = null
    glows.clear()
    preparedFor = -1L
  }

  private fun ensurePrepared(slice: SpoilerSlice) {
    val key = (slice.width.toLong() shl 20) xor slice.height.toLong()
    if (key == preparedFor) return
    preparedFor = key
    width = slice.width
    height = slice.height
    textBitmap = null
    glows.clear()
    random = Random(slice.start * 31L + slice.index * 7L + slice.width.toLong())
    prepare(slice)
  }

  // ---- the words

  private fun text(slice: SpoilerSlice): Bitmap =
    textBitmap ?: Bitmap.createBitmap(max(1, width.roundToInt()), max(1, height.roundToInt()), Bitmap.Config.ARGB_8888).also {
      slice.drawText(Canvas(it))
      textBitmap = it
    }

  /** The words, sharp, at [alpha]. */
  protected fun drawWords(
    canvas: Canvas,
    slice: SpoilerSlice,
    alpha: Float,
  ) {
    if (alpha <= 0.01f) return
    bitmapPaint.alpha = (alpha * 255).roundToInt()
    canvas.drawBitmap(text(slice), 0f, 0f, bitmapPaint)
  }

  /** The words blurred by [radius] and tinted [color]: a ghost of them, or a glow around them. */
  protected fun drawGlow(
    canvas: Canvas,
    slice: SpoilerSlice,
    color: Int,
    alpha: Float,
    radius: Float,
  ) {
    if (alpha <= 0.01f) return
    val key = (radius * 4).roundToInt()
    val (glow, offset) =
      glows.getOrPut(key) {
        val offset = IntArray(2)
        val blur = Paint().apply { maskFilter = BlurMaskFilter(max(0.5f, radius), BlurMaskFilter.Blur.NORMAL) }
        text(slice).extractAlpha(blur, offset) to offset
      }
    fill.shader = null
    fill.color = color
    fill.alpha = (alpha * 255).roundToInt()
    canvas.drawBitmap(glow, offset[0].toFloat(), offset[1].toFloat(), fill)
  }

  // ---- masks

  /** Draws [block], then keeps only what lies ahead of or behind [head], feathered over [feather]. */
  protected inline fun sweep(
    canvas: Canvas,
    head: Float,
    feather: Float,
    keepsAhead: Boolean,
    block: () -> Unit,
  ) {
    val saved = canvas.saveLayer(0f, 0f, width, height, null)
    block()
    val colors = if (keepsAhead) intArrayOf(0, WHITE) else intArrayOf(WHITE, 0)
    maskPaint.shader = LinearGradient(head - feather, 0f, head + feather, 0f, colors, null, Shader.TileMode.CLAMP)
    canvas.drawRect(0f, 0f, width, height, maskPaint)
    canvas.restoreToCount(saved)
  }

  /** Draws [block], then keeps only what lies inside or outside a circle, feathered at its rim. */
  protected inline fun bloom(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    radius: Float,
    feather: Float,
    keepsInside: Boolean,
    block: () -> Unit,
  ) {
    val saved = canvas.saveLayer(0f, 0f, width, height, null)
    block()
    val outer = max(radius + feather, 0.5f)
    val inner = (max(0f, radius - feather) / outer).coerceIn(0f, 0.999f)
    val colors = if (keepsInside) intArrayOf(WHITE, WHITE, 0) else intArrayOf(0, 0, WHITE)
    maskPaint.shader = RadialGradient(cx, cy, outer, colors, floatArrayOf(0f, inner, 1f), Shader.TileMode.CLAMP)
    canvas.drawRect(0f, 0f, width, height, maskPaint)
    canvas.restoreToCount(saved)
  }

  /** Draws [block] with its edges faded out over [x] at the sides and [y] at the top and bottom, so nothing ends on the slice's box. */
  protected inline fun feathered(
    canvas: Canvas,
    x: Float,
    y: Float,
    block: () -> Unit,
  ) {
    val saved = canvas.saveLayer(0f, 0f, width, height, null)
    block()
    if (x > 0f) {
      val f = (x / width).coerceAtMost(0.5f)
      maskPaint.shader = LinearGradient(0f, 0f, width, 0f, intArrayOf(0, WHITE, WHITE, 0), floatArrayOf(0f, f, 1f - f, 1f), Shader.TileMode.CLAMP)
      canvas.drawRect(0f, 0f, width, height, maskPaint)
    }
    if (y > 0f) {
      val f = (y / height).coerceAtMost(0.5f)
      maskPaint.shader = LinearGradient(0f, 0f, 0f, height, intArrayOf(0, WHITE, WHITE, 0), floatArrayOf(0f, f, 1f - f, 1f), Shader.TileMode.CLAMP)
      canvas.drawRect(0f, 0f, width, height, maskPaint)
    }
    canvas.restoreToCount(saved)
  }

  /** The page itself ahead of a front, so the words stay hidden until it passes. */
  protected fun pageAhead(
    canvas: Canvas,
    head: Float,
    feather: Float,
  ) {
    sweep(canvas, head, feather, keepsAhead = true) { canvas.drawColor(page) }
  }

  // ---- shapes

  /** A radial gradient from [color] to clear, squashed to an ellipse: a cloud, a glow, a shadow. */
  protected fun softEllipse(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    rx: Float,
    ry: Float,
    color: Int,
    alpha: Float = 1f,
    core: Float = 0f,
  ) {
    if (alpha <= 0.01f || rx <= 0f || ry <= 0f) return
    val shader =
      gradients.getOrPut(color * 31 + (core * 10).roundToInt()) {
        RadialGradient(0f, 0f, 1f, intArrayOf(color, color, color and 0x00FFFFFF), floatArrayOf(0f, core, 1f), Shader.TileMode.CLAMP)
      }
    fill.shader = shader
    fill.alpha = (alpha * 255).roundToInt()
    val saved = canvas.save()
    canvas.translate(cx, cy)
    canvas.scale(rx, ry)
    canvas.drawCircle(0f, 0f, 1f, fill)
    canvas.restoreToCount(saved)
    fill.shader = null
  }

  protected fun circle(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    radius: Float,
    color: Int,
    alpha: Float = 1f,
  ) {
    if (alpha <= 0.01f) return
    fill.shader = null
    fill.color = color
    fill.alpha = (alpha * 255).roundToInt()
    canvas.drawCircle(cx, cy, radius, fill)
  }

  protected fun line(
    canvas: Canvas,
    x0: Float,
    y0: Float,
    x1: Float,
    y1: Float,
    widthPx: Float,
    color: Int,
    alpha: Float = 1f,
  ) {
    if (alpha <= 0.01f) return
    stroke.shader = null
    stroke.strokeWidth = widthPx
    stroke.color = color
    stroke.alpha = (alpha * 255).roundToInt()
    canvas.drawLine(x0, y0, x1, y1, stroke)
  }

  protected fun strokePath(
    canvas: Canvas,
    p: Path,
    widthPx: Float,
    color: Int,
    alpha: Float = 1f,
  ) {
    if (alpha <= 0.01f) return
    stroke.shader = null
    stroke.strokeWidth = widthPx
    stroke.color = color
    stroke.alpha = (alpha * 255).roundToInt()
    canvas.drawPath(p, stroke)
  }

  protected fun fillPath(
    canvas: Canvas,
    p: Path,
    color: Int,
    alpha: Float = 1f,
  ) {
    if (alpha <= 0.01f) return
    fill.shader = null
    fill.color = color
    fill.alpha = (alpha * 255).roundToInt()
    canvas.drawPath(p, fill)
  }

  /** A four-point star, the shape of a glint. */
  protected fun star(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    size: Float,
    color: Int,
    alpha: Float,
  ) {
    if (alpha <= 0.01f) return
    val waist = size * 0.22f
    path.reset()
    path.moveTo(cx, cy - size)
    path.lineTo(cx + waist, cy - waist)
    path.lineTo(cx + size, cy)
    path.lineTo(cx + waist, cy + waist)
    path.lineTo(cx, cy + size)
    path.lineTo(cx - waist, cy + waist)
    path.lineTo(cx - size, cy)
    path.lineTo(cx - waist, cy - waist)
    path.close()
    fillPath(canvas, path, color, alpha)
  }

  protected fun roundRect(
    canvas: Canvas,
    paint: Paint,
    top: Float = 0f,
    bottom: Float = height,
    radius: Float = 4 * dp,
  ) {
    rect.set(0f, top, width, bottom)
    canvas.drawRoundRect(rect, radius, radius, paint)
  }

  protected fun verticalGradient(
    top: Int,
    bottom: Int,
    from: Float = 0f,
    to: Float = height,
  ): Shader = LinearGradient(0f, from, 0f, to, top, bottom, Shader.TileMode.CLAMP)
}

// The attic: webs spun into the top corners of the line with loose threads sagging between them and
// a spider hanging on its thread; on tap the spider runs the line and the web tears behind it.

data class CobwebSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_300

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = CobwebSlice(host, page)
}

internal class CobwebSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Glint(val x: Float, val y: Float, val phase: Float)

  private class Drape(val x0: Float, val y0: Float, val x1: Float, val y1: Float, val sag: Float)

  private val web = Path()
  // Stroking the web is the costly part, so it is drawn once and only swayed.
  private var webBitmap: Bitmap? = null
  private val webPaint = Paint(Paint.FILTER_BITMAP_FLAG)
  private val glints = ArrayList<Glint>()
  private val drapes = ArrayList<Drape>()
  private var spiderX = 0f
  private var spiderPhase = 0f
  private val silk = 0xFFE9E4F5.toInt()
  private val silver = 0xFFD9D4FF.toInt()
  private val spider = 0xFF140D1C.toInt()
  private val rim = 0xFF9C8FC4.toInt()
  private val eye = 0xFFFF4D4D.toInt()

  override fun prepare(slice: SpoilerSlice) {
    web.reset()
    webBitmap = null
    glints.clear()
    drapes.clear()
    val reach = min(height * 2.6f, width * 0.5f)
    val twoWebs = width > height * 3.2f
    if (twoWebs) {
      cornerWeb(0f, 1f, reach)
      cornerWeb(width, -1f, reach * (0.8f + random.nextFloat() * 0.2f))
      // Loose threads hang between the two webs.
      repeat(2 + random.nextInt(2)) {
        drapes +=
          Drape(
            x0 = reach * (0.3f + random.nextFloat() * 0.35f),
            y0 = height * (0.04f + random.nextFloat() * 0.18f),
            x1 = width - reach * (0.3f + random.nextFloat() * 0.35f),
            y1 = height * (0.04f + random.nextFloat() * 0.18f),
            sag = height * (0.45f + random.nextFloat() * 0.35f),
          )
      }
      spiderX = width * (0.38f + random.nextFloat() * 0.24f)
    } else {
      cornerWeb(0f, 1f, min(width * 1.1f, height * 2.6f))
      spiderX = width * 0.72f
    }
    spiderPhase = random.nextFloat() * TWO_PI
  }

  /** A web in a top corner: spokes fanning out from the corner and rings sagging between them. */
  private fun cornerWeb(
    cx: Float,
    dir: Float,
    reach: Float,
  ) {
    val spokes = 7
    val angles = FloatArray(spokes) { i -> 0.05f + 1.45f * i / (spokes - 1) + (random.nextFloat() - 0.5f) * 0.12f }
    val lengths = FloatArray(spokes) { reach * (0.85f + random.nextFloat() * 0.15f) }
    for (i in 0 until spokes) {
      web.moveTo(cx, 0f)
      web.lineTo(cx + dir * cos(angles[i]) * lengths[i], sin(angles[i]) * lengths[i])
    }
    val rings = 7
    for (r in 1..rings) {
      val f = (r + (random.nextFloat() - 0.5f) * 0.3f) / (rings + 0.3f)
      for (i in 0 until spokes - 1) {
        val x0 = cx + dir * cos(angles[i]) * lengths[i] * f
        val y0 = sin(angles[i]) * lengths[i] * f
        val x1 = cx + dir * cos(angles[i + 1]) * lengths[i + 1] * f
        val y1 = sin(angles[i + 1]) * lengths[i + 1] * f
        // Each strand sags toward the corner, which is what makes it read as a cobweb.
        val sag = 0.22f
        web.moveTo(x0, y0)
        web.quadTo((x0 + x1) / 2 + (cx - (x0 + x1) / 2) * sag, (y0 + y1) / 2 * (1f - sag), x1, y1)
        if (random.nextFloat() < 0.3f && y0 in 0f..height) glints += Glint(x0, y0, random.nextFloat() * TWO_PI)
      }
    }
  }

  override fun onRemoved() {
    super.onRemoved()
    webBitmap = null
  }

  private fun drapeAt(
    d: Drape,
    u: Float,
  ): FloatArray {
    val cx = (d.x0 + d.x1) / 2
    val cy = max(d.y0, d.y1) + d.sag
    val a = (1 - u) * (1 - u)
    val b = 2 * (1 - u) * u
    val c = u * u
    return floatArrayOf(a * d.x0 + b * cx + c * d.x1, a * d.y0 + b * cy + c * d.y1)
  }

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    drawWeb(canvas, slice, time, head = -width)
    // The spider hangs on its thread, bobbing, and every few seconds drops a little and climbs back.
    val cycle = (time + spiderPhase) % 5.2f
    val drop = if (cycle < 1.1f) sin(cycle / 1.1f * PI.toFloat()) * height * 0.16f else 0f
    val sy = height * (0.44f + 0.05f * sin(time * 1.3f + spiderPhase)) + drop
    val sx = spiderX + sin(time * 0.8f + spiderPhase) * 1.5f * dp
    line(canvas, spiderX, 0f, sx, sy - 2 * dp, 0.7f * dp, silk, 0.75f)
    drawSpider(canvas, sx, sy, time, running = false)
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    val feather = 10 * dp
    val trail = 60 * dp
    val head = -feather + (width + trail + 2 * feather) * easeInOut(progress)
    pageAhead(canvas, head, feather)
    drawWeb(canvas, slice, time, head)
    // Torn strands curl back from the tear, and the dew falls off them.
    repeat(4) { i ->
      val y = height * (0.14f + i * 0.24f)
      val flap = sin(time * 16f + i * 1.3f) * 2 * dp
      path.reset()
      path.moveTo(head, y)
      path.quadTo(head - 6 * dp, y + flap, head - 10 * dp, y - 3 * dp + flap)
      strokePath(canvas, path, 0.8f * dp, silk, 0.85f)
    }
    glints.forEach { g ->
      val fall = (head - g.x) / (50 * dp)
      if (fall in 0f..1f) circle(canvas, g.x + 2 * dp, g.y + fall * fall * height * 0.9f, 1.1f * dp, WHITE, 1f - fall)
    }
    sweep(canvas, head - trail, trail, keepsAhead = true) {
      sweep(canvas, head, feather, keepsAhead = false) {
        drawGlow(canvas, slice, silver, 0.9f, 5 * dp)
      }
    }
    // The one on the thread scurries up out of the way, reeling its silk in.
    if (head < spiderX) {
      val sy = height * 0.44f - easeIn((progress / 0.35f).coerceAtMost(1f)) * height * 0.9f
      line(canvas, spiderX, 0f, spiderX, sy - 2 * dp, 0.7f * dp, silk, 0.75f)
      drawSpider(canvas, spiderX, sy, time, running = true)
    }
    if (head < width + 14 * dp) drawSpider(canvas, head + 5 * dp, height * 0.5f + sin(time * 30f) * 0.6f * dp, time, running = true)
  }

  private fun drawWeb(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    head: Float,
  ) {
    sweep(canvas, head, 10 * dp, keepsAhead = true) {
      // Moonlight on the words behind the web.
      drawGlow(canvas, slice, CREAM, 0.22f, 4 * dp)
      // The whole web sways a hair in the draught.
      canvas.drawBitmap(webBitmap ?: drawWebBitmap(), sin(time * 0.7f) * 0.8f * dp, 0f, webPaint)
      glints.forEach { g ->
        val twinkle = (sin(time * 2.6f + g.phase) + 1f) / 2f
        star(canvas, g.x, g.y, (1f + 1.6f * twinkle) * dp, WHITE, twinkle)
      }
      // A dew drop sliding down a loose thread, over and over.
      drapes.firstOrNull()?.let { d ->
        val u = (time * 0.11f) % 1f
        val p = drapeAt(d, 0.15f + 0.7f * u)
        val a = sin(u * PI.toFloat())
        circle(canvas, p[0], p[1], 1.5f * dp, WHITE, 0.85f * a)
        circle(canvas, p[0] - 0.4f * dp, p[1] - 0.4f * dp, 0.5f * dp, WHITE, a)
      }
    }
  }

  private fun drawWebBitmap(): Bitmap {
    val bitmap = Bitmap.createBitmap(max(1, width.roundToInt()), max(1, height.roundToInt()), Bitmap.Config.ARGB_8888)
    val c = Canvas(bitmap)
    strokePath(c, web, 0.75f * dp, silk, 0.62f)
    drapes.forEach { d ->
      val mid = drapeAt(d, 0.5f)
      path.reset()
      path.moveTo(d.x0, d.y0)
      path.quadTo(2 * mid[0] - (d.x0 + d.x1) / 2, 2 * mid[1] - (d.y0 + d.y1) / 2, d.x1, d.y1)
      strokePath(c, path, 0.7f * dp, silk, 0.45f)
    }
    webBitmap = bitmap
    return bitmap
  }

  /** A spider with jointed legs, a red mark on its back and a pale rim so it shows on the dark page. */
  private fun drawSpider(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    time: Float,
    running: Boolean,
  ) {
    val s = 2.8f * dp
    for (i in 0 until 4) {
      val gait = if (running) sin(time * 42f + i * PI.toFloat() / 2) else sin(time * 2f + i) * 0.12f
      val rowY = cy + s * (i - 1.5f) * 0.32f
      for (side in intArrayOf(-1, 1)) {
        val swing = gait * (if (side == 1) 1f else -1f) * s * 0.35f
        val kneeX = cx + side * s * (1.25f + i * 0.12f)
        val kneeY = cy - s * (0.95f - i * 0.25f) + swing
        val footX = cx + side * s * (2.1f + abs(i - 1.5f) * 0.25f)
        val footY = cy + s * (0.25f + i * 0.4f) + swing
        path.reset()
        path.moveTo(cx + side * s * 0.25f, rowY)
        path.lineTo(kneeX, kneeY)
        path.lineTo(footX, footY)
        strokePath(canvas, path, 0.75f * dp, spider)
        strokePath(canvas, path, 0.3f * dp, rim, 0.35f)
      }
    }
    circle(canvas, cx, cy + s * 0.6f, s * 1.08f, rim, 0.5f)
    circle(canvas, cx, cy + s * 0.6f, s * 0.98f, spider)
    circle(canvas, cx, cy - s * 0.45f, s * 0.68f, rim, 0.5f)
    circle(canvas, cx, cy - s * 0.45f, s * 0.6f, spider)
    // The hourglass.
    path.reset()
    path.moveTo(cx - s * 0.28f, cy + s * 0.3f)
    path.lineTo(cx + s * 0.28f, cy + s * 0.3f)
    path.lineTo(cx, cy + s * 0.62f)
    path.close()
    path.moveTo(cx - s * 0.28f, cy + s * 0.94f)
    path.lineTo(cx + s * 0.28f, cy + s * 0.94f)
    path.lineTo(cx, cy + s * 0.62f)
    path.close()
    fillPath(canvas, path, eye, 0.9f)
    val blink = if ((time * 0.4f + spiderPhase) % 1f < 0.04f) 0f else 1f
    softEllipse(canvas, cx, cy - s * 0.55f, s * 0.7f, s * 0.45f, eye, 0.35f * blink)
    circle(canvas, cx - s * 0.22f, cy - s * 0.58f, s * 0.14f, eye, blink)
    circle(canvas, cx + s * 0.22f, cy - s * 0.58f, s * 0.14f, eye, blink)
  }
}

// The crypt: green mist with a shape of the words in it, and will-o'-the-wisps drifting through;
// a cold draught sweeps it along the line.

data class CryptFogSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_300

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = CryptFogSlice(host, page)
}

internal class CryptFogSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Bank(val x: Float, val y: Float, val rx: Float, val ry: Float, val speed: Float, val phase: Float, val pale: Boolean)

  private class Mote(val x: Float, val speed: Float, val phase: Float)

  private val banks = ArrayList<Bank>()
  private val streaks = ArrayList<Bank>()
  private val motes = ArrayList<Mote>()
  private val wisps = ArrayList<Float>()
  private val mist = 0xFF4F8466.toInt()
  private val paleMist = 0xFF8FBF9F.toInt()
  private val ghost = 0xFFBBF7D0.toInt()
  private val glowGreen = 0xFF6EE7B7.toInt()
  private val wispCore = 0xFFE8FFF1.toInt()

  override fun prepare(slice: SpoilerSlice) {
    banks.clear()
    streaks.clear()
    motes.clear()
    wisps.clear()
    repeat((width / (9 * dp)).roundToInt().coerceIn(6, 40)) {
      banks +=
        Bank(
          x = random.nextFloat() * width,
          y = height * (0.3f + random.nextFloat() * 0.5f),
          rx = height * (0.6f + random.nextFloat() * 0.5f),
          ry = height * (0.4f + random.nextFloat() * 0.3f),
          speed = (3f + random.nextFloat() * 5f) * dp,
          phase = random.nextFloat() * TWO_PI,
          pale = random.nextFloat() < 0.4f,
        )
    }
    // Thin fast tendrils over the banks, so it reads as mist and not as a cloud.
    repeat((width / (40 * dp)).roundToInt().coerceIn(2, 6)) {
      streaks +=
        Bank(
          x = random.nextFloat() * width,
          y = height * (0.3f + random.nextFloat() * 0.4f),
          rx = max(height * 1.5f, width * (0.2f + random.nextFloat() * 0.15f)),
          ry = height * (0.1f + random.nextFloat() * 0.06f),
          speed = (10f + random.nextFloat() * 8f) * dp,
          phase = random.nextFloat() * TWO_PI,
          pale = true,
        )
    }
    repeat((width / (16 * dp)).roundToInt().coerceIn(2, 18)) {
      motes += Mote(random.nextFloat() * width, height * (0.15f + random.nextFloat() * 0.2f), random.nextFloat() * height)
    }
    repeat(if (width > 60 * dp) 2 else 1) { wisps += random.nextFloat() * TWO_PI }
  }

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    feathered(canvas, 8 * dp, height * 0.22f) { drawMist(canvas, slice, time, head = -width) }
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    val feather = 14 * dp
    val trail = 60 * dp
    val head = -feather + (width + trail + 2 * feather) * easeInOut(progress)
    pageAhead(canvas, head, feather)
    feathered(canvas, 8 * dp, height * 0.22f) { drawMist(canvas, slice, time, head) }
    sweep(canvas, head - trail, trail, keepsAhead = true) {
      sweep(canvas, head, feather, keepsAhead = false) {
        drawGlow(canvas, slice, glowGreen, 0.9f, 5 * dp)
      }
    }
  }

  private fun wispAt(
    phase: Float,
    t: Float,
  ): FloatArray =
    floatArrayOf(
      width * (0.5f + 0.42f * sin(t * 0.5f + phase)),
      height * (0.5f + 0.28f * sin(t * 0.83f + phase * 2)),
    )

  private fun drawMist(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    head: Float,
  ) {
    val span = width + 2 * height
    banks.forEach { b ->
      var x = ((b.x + time * b.speed) % span) - height
      val y = b.y + sin(time * 0.6f + b.phase) * height * 0.08f
      val breathe = 1f + 0.08f * sin(time * 0.9f + b.phase)
      val ahead = x - head
      if (ahead < 0f) return@forEach
      var squash = 1f
      if (ahead < 40 * dp) {
        x += (1f - ahead / (40 * dp)) * 14 * dp
        squash = 0.7f + 0.3f * (ahead / (40 * dp))
      }
      softEllipse(canvas, x, y, b.rx * breathe, b.ry * squash, if (b.pale) paleMist else mist, if (b.pale) 0.42f else 0.55f, core = 0.15f)
    }
    val reach = width + 2 * width
    streaks.forEach { b ->
      val x = ((b.x + time * b.speed) % reach) - width
      if (x + b.rx * 0.5f < head) return@forEach
      softEllipse(canvas, x, b.y + sin(time * 0.8f + b.phase) * height * 0.06f, b.rx, b.ry, paleMist, 0.4f, core = 0.3f)
    }
    // Something under it: the shape of the words, blurred, showing through the mist.
    sweep(canvas, head, 10 * dp, keepsAhead = true) {
      drawGlow(canvas, slice, ghost, 0.32f, 3.5f * dp)
    }
    // Cold breath rising out of the mist.
    motes.forEach { m ->
      val y = height - ((time * m.speed + m.phase) % height)
      val x = m.x + sin(time * 1.5f + m.phase) * 3 * dp
      if (x < head) return@forEach
      circle(canvas, x, y, 0.9f * dp, ghost, 0.5f * (y / height))
    }
    // Will-o'-the-wisps wander through the mist with a trail; the draught sends them fleeing.
    wisps.forEach { phase ->
      val at = wispAt(phase, time)
      val flee = ((head + 30 * dp - at[0]) / (30 * dp)).coerceIn(0f, 1f)
      for (k in 4 downTo 0) {
        val p = wispAt(phase, time - k * 0.07f)
        val x = p[0] + flee * flee * width * 0.6f
        val y = p[1] - flee * height * 1.5f
        val a = (1f - k / 5f) * (1f - flee)
        softEllipse(canvas, x, y, (6f - k) * dp, (5f - k * 0.8f) * dp, glowGreen, 0.55f * a, core = 0.3f)
        if (k == 0) circle(canvas, x, y, 1.6f * dp, wispCore, 0.95f * a)
      }
    }
  }
}

// The porch: a row of jack-o'-lanterns sitting on the words, carved faces lit from inside, each with
// its own flicker and blink; on tap the candles flare one after another and the pumpkins burst into
// embers.

data class LanternSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_400

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = LanternSlice(host, page)
}

internal class LanternSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Pumpkin(
    val cx: Float,
    val w: Float,
    val h: Float,
    val top: Float,
    val phase: Float,
    val eyes: Path,
    val mouth: Path,
    val rind: Shader,
  )

  private class Ember(val pumpkin: Int, val angle: Float, val speed: Float, val size: Float)

  private val pumpkins = ArrayList<Pumpkin>()
  private val embers = ArrayList<Ember>()
  private val rindLight = 0xFFF2902E.toInt()
  private val rindMid = 0xFFD2601A.toInt()
  private val rindDark = 0xFF6E2206.toInt()
  private val groove = 0xFF4A1604.toInt()
  private val stem = 0xFF5B6B2A.toInt()
  private val cavity = 0xFF2A0A02.toInt()
  private val candle = 0xFFFFE08A.toInt()
  private val amber = 0xFFFF9A1F.toInt()

  override val lineStagger get() = 0.25f

  override fun prepare(slice: SpoilerSlice) {
    pumpkins.clear()
    embers.clear()
    val bodyH = height * 0.8f
    val bodyW = bodyH * 1.32f
    val count = max(1, (width / (bodyW * 1.06f)).toInt())
    val slot = width / count
    repeat(count) { i ->
      val scale = 0.86f + random.nextFloat() * 0.14f
      val w = min(bodyW, slot * 0.98f) * scale
      val h = bodyH * scale
      val cx = slot * (i + 0.5f) + (random.nextFloat() - 0.5f) * (slot - w) * 0.25f
      val top = height * 0.985f - h
      pumpkins += Pumpkin(cx, w, h, top, random.nextFloat() * TWO_PI, carveEyes(cx, top, w, h), carveMouth(cx, top, w, h), rind(cx, top, w, h))
      repeat(7) { embers += Ember(i, -PI.toFloat() * (0.1f + random.nextFloat() * 0.8f), 0.6f + random.nextFloat() * 0.8f, 0.6f + random.nextFloat() * 0.9f) }
    }
  }

  private fun rind(
    cx: Float,
    top: Float,
    w: Float,
    h: Float,
  ): Shader = RadialGradient(cx - w * 0.12f, top + h * 0.35f, w * 0.75f, intArrayOf(rindLight, rindMid, rindDark), floatArrayOf(0f, 0.5f, 1f), Shader.TileMode.CLAMP)

  private fun carveEyes(
    cx: Float,
    top: Float,
    w: Float,
    h: Float,
  ): Path {
    val p = Path()
    val e = h * 0.22f
    val y = top + h * 0.38f
    val slant = (random.nextFloat() - 0.3f) * e * 0.35f
    for (side in intArrayOf(-1, 1)) {
      val x = cx + side * w * 0.18f
      p.moveTo(x - e * 0.62f, y + e * 0.42f + side * slant * 0.3f)
      p.lineTo(x + e * 0.62f, y + e * 0.42f - side * slant * 0.3f)
      p.lineTo(x - side * e * 0.12f, y - e * 0.55f + slant)
      p.close()
    }
    // A small nose.
    val n = h * 0.08f
    p.moveTo(cx - n, top + h * 0.58f)
    p.lineTo(cx + n, top + h * 0.58f)
    p.lineTo(cx, top + h * 0.48f)
    p.close()
    return p
  }

  /** A grin with a tooth hanging from the top lip and one standing on the bottom. */
  private fun carveMouth(
    cx: Float,
    top: Float,
    w: Float,
    h: Float,
  ): Path {
    val p = Path()
    val l = cx - w * 0.3f
    val r = cx + w * 0.3f
    val t = top + h * 0.64f
    val b = top + h * 0.86f
    val tooth = if (random.nextBoolean()) -1f else 1f
    p.moveTo(l, t - h * 0.06f)
    p.quadTo(cx - w * 0.16f, t + h * 0.05f, cx + tooth * w * 0.08f - w * 0.04f, t + h * 0.05f)
    p.lineTo(cx + tooth * w * 0.08f, t + h * 0.14f)
    p.lineTo(cx + tooth * w * 0.08f + w * 0.04f, t + h * 0.05f)
    p.quadTo(cx + w * 0.16f, t + h * 0.05f, r, t - h * 0.06f)
    p.quadTo(cx + w * 0.22f, b, cx - tooth * w * 0.1f + w * 0.05f, b - h * 0.01f)
    p.lineTo(cx - tooth * w * 0.1f, b - h * 0.1f)
    p.lineTo(cx - tooth * w * 0.1f - w * 0.05f, b - h * 0.01f)
    p.quadTo(cx - w * 0.22f, b, l, t - h * 0.06f)
    p.close()
    return p
  }

  private fun flicker(
    time: Float,
    phase: Float,
  ): Float = 0.75f + 0.13f * sin(time * 9f + phase) + 0.12f * sin(time * 23f + phase * 2)

  /** 1 with the eyes open, 0 shut: a quick blink every few seconds, at its own time for each. */
  private fun lids(
    time: Float,
    phase: Float,
  ): Float {
    val cycle = (time + phase * 0.6f) % 4.1f
    return if (cycle < 0.24f) abs(cos(cycle / 0.24f * PI.toFloat())) else 1f
  }

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    // Now and then one of them cackles: its face flares and it hops.
    val turn = (time / 2.9f).toInt()
    val cackling = ((turn * 7919) % pumpkins.size + pumpkins.size) % pumpkins.size
    val within = (time % 2.9f) / 2.9f
    pumpkins.forEachIndexed { i, p ->
      val cackle = if (i == cackling && within < 0.3f) sin(within / 0.3f * PI.toFloat()) else 0f
      val hop = if (cackle > 0f) abs(sin(within / 0.3f * 3 * PI.toFloat())) * 1.2f * dp * cackle else 0f
      drawPumpkin(canvas, p, flicker(time, p.phase) + cackle * 0.5f, lids(time, p.phase), lift = hop, swell = 1f, alpha = 1f)
    }
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    // A wave runs along the row: each candle flares as it nears, then its pumpkin bursts.
    val front = -10 * dp + (width + 20 * dp) * (progress / 0.6f)
    pageAhead(canvas, front, 14 * dp)
    sweep(canvas, front - 50 * dp, 50 * dp, keepsAhead = true) {
      sweep(canvas, front, 14 * dp, keepsAhead = false) {
        drawGlow(canvas, slice, amber, 0.85f, 6 * dp)
        drawGlow(canvas, slice, candle, 0.6f, 2.5f * dp)
      }
    }
    pumpkins.forEachIndexed { i, p ->
      val start = (p.cx / (width + 20 * dp)) * 0.6f
      val burst = ((progress - start) / 0.4f).coerceIn(0f, 1f)
      val warm = ((progress - (start - 0.18f)) / 0.18f).coerceIn(0f, 1f)
      if (burst < 0.35f) {
        val flash = if (burst > 0f) sin(burst / 0.35f * PI.toFloat() / 2) else 0f
        val shake = sin(time * 70f + p.phase) * 0.7f * dp * warm
        val saved = canvas.save()
        canvas.translate(shake, 0f)
        drawPumpkin(canvas, p, flicker(time, p.phase) + warm * 0.7f + flash * 1.2f, 1f, lift = 0f, swell = 1f + flash * 0.1f, alpha = 1f - flash * 0.4f)
        canvas.restoreToCount(saved)
      }
      if (burst > 0f) {
        // The shell is gone in a flash of candlelight; embers fly up and out and cool.
        val pop = easeOut(burst)
        val cy = p.top + p.h * 0.55f
        softEllipse(canvas, p.cx, cy, p.w * (0.5f + pop * 0.6f), min(p.h * (0.5f + pop * 0.3f), height * 0.5f), amber, 0.7f * (1f - burst), core = 0.2f)
        embers.forEach { e ->
          if (e.pumpkin != i) return@forEach
          val r = p.w * (0.15f + pop * 0.9f * e.speed)
          val x = p.cx + cos(e.angle) * r
          val y = cy + sin(e.angle) * r * 0.3f + burst * burst * p.h * 0.3f
          circle(canvas, x, y, e.size * dp, if (burst < 0.5f) candle else amber, (1f - burst) * 0.95f)
        }
      }
    }
  }

  private fun drawPumpkin(
    canvas: Canvas,
    p: Pumpkin,
    glow: Float,
    open: Float,
    lift: Float,
    swell: Float,
    alpha: Float,
  ) {
    val cy = p.top + p.h / 2
    val saved = canvas.save()
    canvas.scale(swell, swell, p.cx, p.top + p.h)
    canvas.translate(0f, -lift)
    // Shadow on the page, then the stem, then three lobes, the middle one in front.
    softEllipse(canvas, p.cx, p.top + p.h * 0.97f + lift, p.w * 0.55f, p.h * 0.08f, 0xFF000000.toInt(), 0.5f * alpha)
    path.reset()
    path.moveTo(p.cx - p.w * 0.05f, p.top + p.h * 0.1f)
    path.quadTo(p.cx - p.w * 0.04f, p.top - p.h * 0.1f, p.cx + p.w * 0.07f, p.top - p.h * 0.16f)
    path.lineTo(p.cx + p.w * 0.09f, p.top - p.h * 0.1f)
    path.quadTo(p.cx + p.w * 0.04f, p.top - p.h * 0.04f, p.cx + p.w * 0.05f, p.top + p.h * 0.1f)
    path.close()
    fillPath(canvas, path, stem, alpha)
    fill.shader = p.rind
    fill.alpha = (255 * alpha).roundToInt()
    for (side in intArrayOf(-1, 1)) {
      canvas.drawOval(p.cx + side * p.w * 0.2f - p.w * 0.3f, p.top + p.h * 0.03f, p.cx + side * p.w * 0.2f + p.w * 0.3f, p.top + p.h, fill)
    }
    canvas.drawOval(p.cx - p.w * 0.3f, p.top, p.cx + p.w * 0.3f, p.top + p.h, fill)
    fill.shader = null
    stroke.shader = null
    stroke.strokeWidth = 0.8f * dp
    stroke.color = groove
    stroke.alpha = (150 * alpha).roundToInt()
    canvas.drawOval(p.cx - p.w * 0.3f, p.top, p.cx + p.w * 0.3f, p.top + p.h, stroke)
    // The carving: dark where the knife went deep, lit from the candle, hottest at the middle.
    val g = glow.coerceAtMost(1f)
    softEllipse(canvas, p.cx, cy + p.h * 0.1f, p.w * 0.42f, p.h * 0.42f, amber, 0.35f * g * alpha, core = 0.2f)
    canvas.save()
    canvas.translate(0f, 0.6f * dp)
    fillPath(canvas, p.mouth, cavity, alpha)
    canvas.restore()
    fillPath(canvas, p.mouth, amber, g * alpha)
    fillPath(canvas, p.mouth, candle, (glow - 0.35f).coerceIn(0f, 1f) * alpha)
    canvas.save()
    canvas.scale(1f, open.coerceAtLeast(0.08f), p.cx, p.top + p.h * 0.4f)
    canvas.save()
    canvas.translate(0f, 0.6f * dp)
    fillPath(canvas, p.eyes, cavity, alpha)
    canvas.restore()
    fillPath(canvas, p.eyes, amber, g * alpha)
    fillPath(canvas, p.eyes, candle, (glow - 0.35f).coerceIn(0f, 1f) * alpha)
    if (glow > 1f) fillPath(canvas, p.eyes, WHITE, (glow - 1f).coerceAtMost(1f) * alpha)
    canvas.restore()
    if (glow > 1f) fillPath(canvas, p.mouth, WHITE, ((glow - 1f) * 0.8f).coerceAtMost(1f) * alpha)
    canvas.restoreToCount(saved)
  }
}

// The nursery: little ghosts in sheets bobbing over the words, fading in and out; on tap each one
// swells with a shriek and whooshes off into the distance.

data class GhostSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_300

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = GhostSlice(host, page)
}

internal class GhostSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Ghost(val x: Float, val size: Float, val phase: Float, val dir: Float, val alpha: Float)

  private val ghosts = ArrayList<Ghost>()
  private val sheet = Path()
  private val sheetWhite = 0xFFF7F4FF.toInt()
  private val sheetShade = 0xFFB9B0DA.toInt()
  private val eyes = 0xFF201833.toInt()
  private val blush = 0xFFFF9EC4.toInt()
  private val chill = 0xFFE9E5FF.toInt()
  private lateinit var shade: Shader

  override fun prepare(slice: SpoilerSlice) {
    ghosts.clear()
    val size = height * 0.9f
    val count = (width / (size * 1.15f)).roundToInt().coerceIn(1, 16)
    repeat(count) { i ->
      ghosts +=
        Ghost(
          x = width * (i + 0.5f) / count + (random.nextFloat() - 0.5f) * size * 0.2f,
          size = size * (0.84f + random.nextFloat() * 0.16f),
          phase = random.nextFloat() * TWO_PI,
          dir = if (random.nextBoolean()) 1f else -1f,
          alpha = 0.86f + random.nextFloat() * 0.14f,
        )
    }
    shade = verticalGradient(sheetWhite, sheetShade, 0f, height)
  }

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    drawGlow(canvas, slice, chill, 0.14f, 4 * dp)
    // Now and then one of them fades almost through, the way ghosts do.
    val turn = (time / 2.3f).toInt()
    val fading = ((turn * 7919) % ghosts.size + ghosts.size) % ghosts.size
    val within = (time % 2.3f) / 2.3f
    ghosts.forEachIndexed { i, g ->
      val fade = if (i == fading && within < 0.5f) sin(within / 0.5f * PI.toFloat()) else 0f
      val wave = if (i == fading && within in 0.5f..0.8f) sin((within - 0.5f) / 0.3f * PI.toFloat()) else 0f
      drawGhost(canvas, g, time, g.x, height / 2, 1f, shriek = 0f, wave = wave, tilt = 0f, alpha = g.alpha * (1f - 0.65f * fade))
    }
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    drawGlow(canvas, slice, chill, (1f - progress / 0.9f).coerceAtLeast(0f) * 0.9f, 6 * dp)
    ghosts.forEachIndexed { i, g ->
      val start = if (ghosts.size > 1) 0.3f * i / (ghosts.size - 1) else 0f
      val own = ((progress - start) / 0.7f).coerceIn(0f, 1f)
      // Boo: it swells with its mouth wide and shakes, then shrinks away into the distance.
      val shriek = if (own < 0.38f) sin(own / 0.38f * PI.toFloat()) else 0f
      val flee = easeIn(((own - 0.3f) / 0.7f).coerceIn(0f, 1f))
      if (flee > 0f) {
        for (k in 2 downTo 1) {
          val back = (flee - k * 0.1f).coerceAtLeast(0f)
          if (back > 0f) drawFleeing(canvas, g, time, back, shriek = 0f, alpha = g.alpha * (1f - flee) * 0.3f / k)
        }
      }
      drawFleeing(canvas, g, time, flee, shriek, g.alpha * (1f - flee))
    }
  }

  private fun drawFleeing(
    canvas: Canvas,
    g: Ghost,
    time: Float,
    flee: Float,
    shriek: Float,
    alpha: Float,
  ) {
    val x = g.x + g.dir * flee * 46 * dp + sin(time * 70f + g.phase) * shriek * 0.8f * dp
    val y = height / 2 - flee * height * 0.2f
    val scale = (1f + shriek * 0.14f) * (1f - flee * 0.8f)
    drawGhost(canvas, g, time, x, y, scale, shriek, wave = shriek, tilt = g.dir * flee * 50f, alpha = alpha)
  }

  private fun drawGhost(
    canvas: Canvas,
    g: Ghost,
    time: Float,
    x: Float,
    y: Float,
    scale: Float,
    shriek: Float,
    wave: Float,
    tilt: Float,
    alpha: Float,
  ) {
    if (alpha <= 0.01f || scale <= 0.02f) return
    val h = g.size
    val w = h * 0.74f
    val cx = x + sin(time * 0.7f + g.phase) * 2.5f * dp
    val cy = y + sin(time * 1.7f + g.phase) * 1f * dp
    val saved = canvas.save()
    canvas.rotate(tilt + sin(time * 0.9f + g.phase) * 5f, cx, cy)
    canvas.scale(scale, scale, cx, cy)
    val top = cy - h / 2
    val hem = cy + h / 2
    softEllipse(canvas, cx, cy, w * 0.95f, h * 0.55f, sheetWhite, 0.2f * alpha)
    // Arms: little bumps on the sides, raised for a wave or a shriek.
    fill.shader = shade
    fill.alpha = (245 * alpha).roundToInt()
    for (side in intArrayOf(-1, 1)) {
      val raised = if (side == 1) wave else shriek
      val ax = cx + side * w * (0.5f + raised * 0.08f)
      val ay = cy + h * (0.06f - raised * 0.2f)
      canvas.drawOval(ax - w * 0.16f, ay - h * 0.08f, ax + w * 0.16f, ay + h * 0.08f, fill)
    }
    sheet.reset()
    sheet.moveTo(cx - w / 2, hem - h * 0.12f)
    sheet.lineTo(cx - w / 2, top + w / 2)
    sheet.arcTo(cx - w / 2, top, cx + w / 2, top + w, 180f, 180f, false)
    sheet.lineTo(cx + w / 2, hem - h * 0.12f)
    // A hem of three scallops that ripple.
    val scallops = 3
    for (k in 0 until scallops) {
      val x0 = cx + w / 2 - w * k / scallops
      val x1 = x0 - w / scallops
      val ripple = sin(time * 5f + g.phase + k * 1.7f) * h * 0.05f
      sheet.quadTo((x0 + x1) / 2, hem + h * 0.08f + ripple, x1, hem - h * 0.12f)
    }
    sheet.close()
    canvas.drawPath(sheet, fill)
    fill.shader = null
    // Eyes that blink, rosy cheeks, and a mouth that opens wide for the shriek.
    val blink = ((time * 0.3f + g.phase) % 1f).let { if (it < 0.035f) 0.15f else 1f }
    val eyeY = top + h * 0.36f
    fill.color = eyes
    fill.alpha = (255 * alpha).roundToInt()
    for (side in intArrayOf(-1, 1)) {
      val ex = cx + side * w * 0.17f
      val ry = h * 0.075f * blink * (1f + shriek * 0.35f)
      canvas.drawOval(ex - w * 0.075f, eyeY - ry, ex + w * 0.075f, eyeY + ry, fill)
    }
    val mouthW = w * (0.07f + shriek * 0.07f)
    val mouthH = h * (0.045f + shriek * 0.11f)
    val mouthY = top + h * 0.56f
    canvas.drawOval(cx - mouthW, mouthY - mouthH, cx + mouthW, mouthY + mouthH, fill)
    for (side in intArrayOf(-1, 1)) {
      softEllipse(canvas, cx + side * w * 0.29f, top + h * 0.5f, w * 0.1f, h * 0.05f, blush, 0.55f * alpha)
    }
    canvas.restoreToCount(saved)
  }
}

// The belfry: bats hanging upside down from a rafter over the words, swaying, one stretching a wing
// now and then; on tap they let go, flip over and flap away, and dust falls off the beam.

data class BatsSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_300

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = BatsSlice(host, page)
}

internal class BatsSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Bat(val x: Float, val size: Float, val phase: Float, val dir: Float, val start: Float, val range: Float)

  private val bats = ArrayList<Bat>()
  private val dust = ArrayList<FloatArray>()
  private val wing = Path()
  private var beam = 0f
  private val fur = 0xFF1C1529.toInt()
  private val furLight = 0xFF362A4D.toInt()
  private val rim = 0xFF9A86D6.toInt()
  private val eye = 0xFFFF3B3B.toInt()
  private val wood = 0xFF3A2A20.toInt()
  private val woodLight = 0xFF6B4F3A.toInt()
  private val violet = 0xFFC4B5FD.toInt()
  private val grit = 0xFFA89A86.toInt()

  override fun prepare(slice: SpoilerSlice) {
    bats.clear()
    dust.clear()
    beam = max(2.4f * dp, height * 0.12f)
    val size = (height - beam) * 0.9f
    val count = (width / (size * 0.72f)).roundToInt().coerceIn(1, 24)
    repeat(count) { i ->
      bats +=
        Bat(
          x = width * (i + 0.5f) / count + (random.nextFloat() - 0.5f) * size * 0.15f,
          size = size * (0.82f + random.nextFloat() * 0.18f),
          phase = random.nextFloat() * TWO_PI,
          dir = if (random.nextBoolean()) 1f else -1f,
          start = random.nextFloat() * 0.3f,
          range = (50 + random.nextFloat() * 40) * dp,
        )
    }
    repeat((width / (6 * dp)).roundToInt().coerceIn(4, 60)) {
      dust += floatArrayOf(random.nextFloat() * width, random.nextFloat(), 0.4f + random.nextFloat() * 0.7f)
    }
  }

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    drawBeam(canvas, 1f)
    // Every couple of seconds one of them stretches a wing and wraps it back.
    val turn = (time / 2.6f).toInt()
    val stretching = ((turn * 7919) % bats.size + bats.size) % bats.size
    val within = (time % 2.6f) / 2.6f
    bats.forEachIndexed { i, b ->
      val open = if (i == stretching && within < 0.45f) sin(within / 0.45f * PI.toFloat()) else 0f
      val swing = sin(time * 1.3f + b.phase) * 5f
      val blink = ((time * 0.25f + b.phase) % 1f).let { if (it < 0.03f) 0f else 1f }
      drawHanging(canvas, b, beam, swing, open, blink, 1f)
    }
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    drawGlow(canvas, slice, violet, (1f - progress / 0.9f).coerceAtLeast(0f) * 0.9f, 6 * dp)
    drawBeam(canvas, (1f - (progress - 0.45f) / 0.4f).coerceIn(0f, 1f))
    // Dust shaken off the rafter.
    dust.forEach { d ->
      val fall = ((progress - d[1] * 0.3f) / 0.6f).coerceIn(0f, 1f)
      if (fall in 0.001f..0.999f) circle(canvas, d[0], beam + fall * fall * height, d[2] * dp, grit, 0.7f * (1f - fall))
    }
    bats.forEach { b ->
      val own = ((progress - b.start) / 0.7f).coerceIn(0f, 1f)
      if (own < 0.25f) {
        // Let go: drop a little and flip over, head up.
        val drop = easeIn(own / 0.25f)
        val saved = canvas.save()
        val center = beam + b.size * 0.5f
        canvas.translate(0f, drop * b.size * 0.15f)
        canvas.rotate(drop * 180f * b.dir, b.x, center)
        drawHanging(canvas, b, beam, 0f, drop, 1f, 1f)
        canvas.restoreToCount(saved)
      } else {
        // Fly off on an arc, wings beating, with a blur of wingbeats behind.
        val f = (own - 0.25f) / 0.75f
        for (k in 2 downTo 0) {
          val back = (f - k * 0.06f).coerceAtLeast(0f)
          val x = b.x + b.dir * b.range * easeIn(back)
          val y = beam + b.size * 0.65f - sin(back * PI.toFloat()) * height * 0.25f
          val flap = if (k == 0) 0.5f + 0.5f * sin(time * 34f + b.phase) else 0.6f
          drawFlying(canvas, x, y, b.size * 0.42f, flap, (1f - f * f) * (if (k == 0) 1f else 0.35f / k))
        }
      }
    }
  }

  private fun drawBeam(
    canvas: Canvas,
    alpha: Float,
  ) {
    if (alpha <= 0.01f) return
    feathered(canvas, 10 * dp, 0f) {
      fill.shader = verticalGradient(woodLight, wood, 0f, beam)
      fill.alpha = (255 * alpha).roundToInt()
      canvas.drawRect(0f, 0f, width, beam, fill)
      fill.shader = null
      line(canvas, 0f, beam * 0.4f, width, beam * 0.45f, 0.5f * dp, 0xFF000000.toInt(), 0.35f * alpha)
      line(canvas, 0f, beam, width, beam, 0.8f * dp, 0xFF000000.toInt(), 0.5f * alpha)
    }
  }

  /** A bat hanging by its feet from [anchor], wings wrapped round it, head and ears pointing down. */
  private fun drawHanging(
    canvas: Canvas,
    b: Bat,
    anchor: Float,
    swing: Float,
    open: Float,
    eyesOpen: Float,
    alpha: Float,
  ) {
    val s = b.size
    val cx = b.x
    val saved = canvas.save()
    canvas.rotate(swing, cx, anchor)
    line(canvas, cx - s * 0.05f, anchor - 0.5f * dp, cx - s * 0.04f, anchor + s * 0.12f, 0.8f * dp, fur, alpha)
    line(canvas, cx + s * 0.05f, anchor - 0.5f * dp, cx + s * 0.04f, anchor + s * 0.12f, 0.8f * dp, fur, alpha)
    // One wing unfurls to the side for a stretch.
    if (open > 0.01f) {
      val d = b.dir
      wing.reset()
      wing.moveTo(cx + d * s * 0.12f, anchor + s * 0.2f)
      wing.lineTo(cx + d * s * (0.22f + 0.4f * open), anchor + s * (0.12f - 0.05f * open))
      wing.quadTo(cx + d * s * (0.2f + 0.3f * open), anchor + s * 0.4f, cx + d * s * (0.24f + 0.34f * open), anchor + s * 0.55f)
      wing.quadTo(cx + d * s * (0.18f + 0.18f * open), anchor + s * 0.55f, cx + d * s * (0.2f + 0.2f * open), anchor + s * 0.72f)
      wing.quadTo(cx + d * s * 0.16f, anchor + s * 0.66f, cx + d * s * 0.1f, anchor + s * 0.66f)
      wing.close()
      fillPath(canvas, wing, fur, alpha)
      strokePath(canvas, wing, 0.6f * dp, rim, 0.6f * alpha)
    }
    // The wrapped body: narrow at the feet, round where the head tucks in.
    wing.reset()
    wing.moveTo(cx - s * 0.07f, anchor + s * 0.1f)
    // The wrists stick up at the shoulders, a claw on each.
    wing.lineTo(cx - s * 0.22f, anchor + s * 0.05f)
    wing.lineTo(cx - s * 0.2f, anchor + s * 0.2f)
    wing.cubicTo(cx - s * 0.27f, anchor + s * 0.35f, cx - s * 0.22f, anchor + s * 0.7f, cx, anchor + s * 0.78f)
    wing.cubicTo(cx + s * 0.22f, anchor + s * 0.7f, cx + s * 0.27f, anchor + s * 0.35f, cx + s * 0.2f, anchor + s * 0.2f)
    wing.lineTo(cx + s * 0.22f, anchor + s * 0.05f)
    wing.lineTo(cx + s * 0.07f, anchor + s * 0.1f)
    wing.close()
    fill.shader = verticalGradient(furLight, fur, anchor, anchor + s * 0.8f)
    fill.alpha = (255 * alpha).roundToInt()
    canvas.drawPath(wing, fill)
    fill.shader = null
    strokePath(canvas, wing, 0.6f * dp, rim, 0.45f * alpha)
    // Where the wings fold over each other.
    path.reset()
    path.moveTo(cx - s * 0.02f, anchor + s * 0.14f)
    path.quadTo(cx + s * 0.12f, anchor + s * 0.45f, cx - s * 0.05f, anchor + s * 0.7f)
    strokePath(canvas, path, 0.5f * dp, rim, 0.4f * alpha)
    // The head, upside down: ears pointing at the floor, red eyes.
    val hy = anchor + s * 0.8f
    circle(canvas, cx, hy, s * 0.14f, fur, alpha)
    for (side in intArrayOf(-1, 1)) {
      path.reset()
      path.moveTo(cx + side * s * 0.03f, hy + s * 0.08f)
      path.lineTo(cx + side * s * 0.13f, hy + s * 0.22f)
      path.lineTo(cx + side * s * 0.13f, hy + s * 0.04f)
      path.close()
      fillPath(canvas, path, fur, alpha)
      strokePath(canvas, path, 0.4f * dp, rim, 0.4f * alpha)
    }
    softEllipse(canvas, cx, hy - s * 0.02f, s * 0.14f, s * 0.07f, eye, 0.4f * alpha * eyesOpen)
    circle(canvas, cx - s * 0.05f, hy - s * 0.02f, s * 0.028f, eye, alpha * eyesOpen)
    circle(canvas, cx + s * 0.05f, hy - s * 0.02f, s * 0.028f, eye, alpha * eyesOpen)
    canvas.restoreToCount(saved)
  }

  /** A bat in flight: body, ears, red eyes and two scalloped wings at [spread] (0 folded, 1 wide). */
  private fun drawFlying(
    canvas: Canvas,
    cx: Float,
    cy: Float,
    s: Float,
    spread: Float,
    alpha: Float,
  ) {
    if (alpha <= 0.01f) return
    val lift = (spread - 0.5f) * s * 0.9f
    wing.reset()
    wing.moveTo(cx, cy - s * 0.45f)
    wing.lineTo(cx - s * 0.18f, cy - s * 0.75f)
    wing.lineTo(cx - s * 0.28f, cy - s * 0.35f)
    wing.quadTo(cx - s * 0.9f, cy - s * 0.6f - lift, cx - s * 1.5f, cy - lift)
    wing.quadTo(cx - s * 1.05f, cy + s * 0.05f - lift * 0.3f, cx - s * 0.8f, cy + s * 0.28f)
    wing.quadTo(cx - s * 0.55f, cy + s * 0.05f, cx - s * 0.3f, cy + s * 0.32f)
    wing.quadTo(cx, cy + s * 0.6f, cx + s * 0.3f, cy + s * 0.32f)
    wing.quadTo(cx + s * 0.55f, cy + s * 0.05f, cx + s * 0.8f, cy + s * 0.28f)
    wing.quadTo(cx + s * 1.05f, cy + s * 0.05f - lift * 0.3f, cx + s * 1.5f, cy - lift)
    wing.quadTo(cx + s * 0.9f, cy - s * 0.6f - lift, cx + s * 0.28f, cy - s * 0.35f)
    wing.lineTo(cx + s * 0.18f, cy - s * 0.75f)
    wing.close()
    fillPath(canvas, wing, fur, alpha)
    strokePath(canvas, wing, 0.6f * dp, rim, 0.55f * alpha)
    circle(canvas, cx - s * 0.1f, cy - s * 0.3f, s * 0.08f, eye, alpha)
    circle(canvas, cx + s * 0.1f, cy - s * 0.3f, s * 0.08f, eye, alpha)
  }
}

// The kitchen: a smear of blood over the words, drips hanging off its ragged edge and letting go;
// a cloth wipes the line clean and the blood runs off its trailing edge.

data class BloodSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_400

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = BloodSlice(host, page)
}

internal class BloodSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Drip(val x: Float, val length: Float, val speed: Float, val phase: Float, val thick: Float)

  private class Spatter(val x: Float, val y: Float, val r: Float)

  private val drips = ArrayList<Drip>()
  private val edges = ArrayList<Float>()
  private val spatter = ArrayList<Spatter>()
  private val smear = Path()
  private val red = 0xFFB3121F.toInt()
  private val bright = 0xFFD91E2E.toInt()
  private val dark = 0xFF4A0410.toInt()
  private val gloss = 0xFFFF8A94.toInt()
  private val glow = 0xFFFF6B6B.toInt()
  private lateinit var body: Shader

  override fun prepare(slice: SpoilerSlice) {
    body = verticalGradient(bright, dark, -height * 0.2f, height * 0.9f)
    // The smear: a lumpy top edge and a bottom edge that bulges where the drips hang.
    val bumps = (width / (12 * dp)).roundToInt().coerceIn(3, 30)
    val step = width / bumps
    val tops = FloatArray(bumps + 1) { height * (0.03f + random.nextFloat() * 0.1f) }
    val bottoms = FloatArray(bumps + 1) { height * (0.46f + random.nextFloat() * 0.12f) }
    smear.reset()
    smear.moveTo(-2 * dp, tops[0])
    for (i in 0 until bumps) {
      smear.quadTo((i + 0.5f) * step, tops[i] - height * 0.06f, (i + 1) * step, tops[i + 1])
    }
    smear.lineTo(width + 2 * dp, bottoms[bumps])
    for (i in bumps downTo 1) {
      smear.quadTo((i - 0.5f) * step, bottoms[i] + height * 0.1f, (i - 1) * step, bottoms[i - 1])
    }
    smear.close()
    drips.clear()
    edges.clear()
    repeat((width / (14 * dp)).roundToInt().coerceIn(3, 24)) {
      val x = random.nextFloat() * width
      val i = (x / step).toInt().coerceIn(0, bumps - 1)
      val edge = bottoms[i] + height * 0.05f
      drips += Drip(x, min(height * (0.14f + random.nextFloat() * 0.22f), height * 0.84f - edge), 0.07f + random.nextFloat() * 0.09f, random.nextFloat(), (1.4f + random.nextFloat() * 2f) * dp)
      edges += edge
    }
    spatter.clear()
    repeat((width / (9 * dp)).roundToInt().coerceIn(4, 40)) {
      spatter += Spatter(random.nextFloat() * width, height * (0.82f + random.nextFloat() * 0.12f), (0.6f + random.nextFloat() * 1.3f) * dp)
    }
  }

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    feathered(canvas, 5 * dp, 0f) { drawSmear(canvas, slice, time, head = -width) }
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    val feather = 6 * dp
    val trail = 40 * dp
    // The cloth wipes left to right; blood is dragged ahead of it and runs off behind.
    val head = -feather + (width + trail + 2 * feather) * easeInOut(progress)
    pageAhead(canvas, head, feather)
    feathered(canvas, 5 * dp, 0f) { drawSmear(canvas, slice, time, head) }
    // The words glow warm in the cloth's wake.
    sweep(canvas, head - trail, trail, keepsAhead = true) {
      sweep(canvas, head, feather, keepsAhead = false) {
        drawGlow(canvas, slice, glow, 0.9f, 5 * dp)
      }
    }
    // Blood piled up against the cloth's edge, with runnels streaming down off it.
    if (head < width + feather) {
      softEllipse(canvas, head - 5 * dp, height * 0.42f, 7 * dp, height * 0.42f, bright, 0.95f, core = 0.4f)
      repeat(3) { i ->
        val y0 = height * (0.25f + i * 0.12f)
        val run = height * (0.25f + i * 0.08f)
        line(canvas, head - 3 * dp, y0, head - 3 * dp - run * 0.3f, y0 + run, 1.6f * dp, red, 0.9f)
        circle(canvas, head - 3 * dp - run * 0.3f, y0 + run, 1.3f * dp, red)
      }
      // The cloth: a fold of linen, soaked red along its leading edge, frayed top and bottom.
      val cloth = 6 * dp
      fill.shader = LinearGradient(head - 1.5f * dp, 0f, head + cloth, 0f, intArrayOf(red, 0xFFEADFC8.toInt(), 0xFFC9BBA0.toInt()), floatArrayOf(0f, 0.35f, 1f), Shader.TileMode.CLAMP)
      fill.alpha = 240
      canvas.drawRect(head - 1.5f * dp, 1.5f * dp, head + cloth, height - 1.5f * dp, fill)
      fill.shader = null
      for (k in 0..3) {
        val x = head + k * cloth / 4
        val fray = (1.2f + (k % 2) * 0.8f) * dp
        line(canvas, x, 1.5f * dp, x - 0.5f * dp, 1.5f * dp - fray, 0.6f * dp, 0xFFEADFC8.toInt(), 0.8f)
        line(canvas, x, height - 1.5f * dp, x + 0.5f * dp, height - 1.5f * dp + fray, 0.6f * dp, 0xFFEADFC8.toInt(), 0.8f)
      }
      line(canvas, head + cloth * 0.6f, 2 * dp, head + cloth * 0.6f, height - 2 * dp, 0.6f * dp, 0xFFB0A184.toInt(), 0.7f)
    }
  }

  private fun drawSmear(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    head: Float,
  ) {
    sweep(canvas, head, 8 * dp, keepsAhead = true) {
      // A shadow under the smear, the body of it, then the words showing through as darker stains.
      canvas.save()
      canvas.translate(0f, 1.5f * dp)
      fillPath(canvas, smear, dark, 0.7f)
      canvas.restore()
      fill.shader = body
      fill.alpha = 255
      canvas.drawPath(smear, fill)
      fill.shader = null
      drawGlow(canvas, slice, dark, 0.55f, 2.5f * dp)
      // Wet highlight along the upper half, and a moving glint.
      fill.shader = verticalGradient(gloss, gloss and 0x00FFFFFF, height * 0.05f, height * 0.42f)
      fill.alpha = 110
      canvas.drawPath(smear, fill)
      fill.shader = null
      val gx = ((time * 11 * dp) % (width + 40 * dp)) - 20 * dp
      softEllipse(canvas, gx, height * 0.18f, 10 * dp, 2.5f * dp, gloss, 0.35f)
      // Spatter around the foot of the line.
      spatter.forEach { s -> circle(canvas, s.x, s.y, s.r, red, 0.85f) }
    }
    drips.forEachIndexed { i, d ->
      if (d.x < head - 6 * dp) return@forEachIndexed
      val edge = edges.getOrElse(i) { height * 0.7f }
      val cycle = ((time * d.speed + d.phase) % 1f)
      val len = d.length * (0.25f + 0.75f * cycle)
      val tip = edge + len
      // A tapering runnel with a swelling bead, and a highlight on its shoulder.
      path.reset()
      path.moveTo(d.x - d.thick * 0.9f, edge - 3 * dp)
      path.quadTo(d.x - d.thick * 0.25f, edge + len * 0.5f, d.x - d.thick * 0.35f, tip)
      path.lineTo(d.x + d.thick * 0.35f, tip)
      path.quadTo(d.x + d.thick * 0.25f, edge + len * 0.5f, d.x + d.thick * 0.9f, edge - 3 * dp)
      path.close()
      fillPath(canvas, path, red)
      circle(canvas, d.x, tip, d.thick * (0.6f + cycle * 0.5f), bright)
      circle(canvas, d.x - d.thick * 0.25f, tip - d.thick * 0.35f, d.thick * 0.22f, gloss, 0.85f)
      // Near the end of its run the bead lets go, falls, and splashes at the foot of the line.
      if (cycle > 0.8f) {
        val fall = (cycle - 0.8f) / 0.2f
        val y = tip + fall * fall * (height - 1.5f * dp - tip)
        circle(canvas, d.x, y, d.thick * 0.6f, bright, 1f - fall * 0.3f)
        if (fall > 0.8f) {
          val burst = (fall - 0.8f) / 0.2f
          circle(canvas, d.x - 2 * dp * burst, height - 1.5f * dp, d.thick * 0.3f, red, 1f - burst)
          circle(canvas, d.x + 2.5f * dp * burst, height - 1.5f * dp, d.thick * 0.25f, red, 1f - burst)
        }
      }
    }
  }
}

// The cellar: darkness, one candle flame wandering along the line and a moth circling it; the flame
// flares and lights the words.

data class CandleSpoiler(
  val page: Int = GUEST_BOOK_PAGE,
) : CustomSpoilerOverlay {
  override val revealDurationMillis: Long get() = 1_300

  override fun createSliceOverlay(
    host: SpoilerOverlayHost,
    style: SpoilerStyle,
  ): SpoilerSliceOverlay = CandleSlice(host, page)
}

internal class CandleSlice(
  host: SpoilerOverlayHost,
  page: Int,
) : HauntedSlice(host, page) {
  private class Mote(val x: Float, val y: Float, val size: Float, val phase: Float)

  private val motes = ArrayList<Mote>()
  private val flame = Path()
  private var wander = 0f
  private val shadow = 0xFF05030A.toInt()
  private val warm = 0xFFFFC56B.toInt()
  private val hot = 0xFFFFF1C2.toInt()
  private val ember = 0xFFFF8C42.toInt()
  private val smoke = 0xFF9A8FA8.toInt()
  private val moth = 0xFFD9CBA3.toInt()

  override fun prepare(slice: SpoilerSlice) {
    wander = random.nextFloat() * TWO_PI
    motes.clear()
    repeat((width / (8 * dp)).roundToInt().coerceIn(6, 50)) {
      motes += Mote(random.nextFloat() * width, random.nextFloat() * height, (0.5f + random.nextFloat() * 0.9f) * dp, random.nextFloat() * TWO_PI)
    }
  }

  private fun flameX(time: Float) = width * (0.5f + 0.32f * sin(time * 0.35f + wander))

  private fun flameY(time: Float) = height * (0.5f + 0.12f * sin(time * 0.55f + wander * 2))

  override fun drawIdle(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
  ) {
    val fx = flameX(time)
    val fy = flameY(time)
    feathered(canvas, 8 * dp, height * 0.22f) {
      drawShadows(canvas, time, 1f)
      // The flame lights the nearest words, too dimly to read.
      bloom(canvas, fx, fy, 14 * dp, 14 * dp, keepsInside = true) {
        drawGlow(canvas, slice, warm, 0.5f, 4 * dp)
      }
      drawMotes(canvas, time, fx, fy, reach = 44 * dp, lit = 0f)
      drawFlame(canvas, fx, fy, time, swell = 0f, presence = 1f)
      drawMoth(canvas, fx, fy, time, flee = 0f)
    }
  }

  override fun drawRevealing(
    canvas: Canvas,
    slice: SpoilerSlice,
    time: Float,
    progress: Float,
  ) {
    val fx = flameX(time)
    val fy = flameY(time)
    val feather = 30 * dp
    val reach = hypot(width, height) + feather
    val bloomed = easeInOut(progress)
    val radius = reach * bloomed
    bloom(canvas, fx, fy, radius, feather, keepsInside = false) {
      canvas.drawColor(page)
      drawShadows(canvas, time, 1f)
    }
    feathered(canvas, 8 * dp, height * 0.2f) {
      bloom(canvas, fx, fy, radius, feather, keepsInside = true) {
        drawGlow(canvas, slice, warm, (1f - progress / 0.85f).coerceAtLeast(0f), 6 * dp)
      }
      if (bloomed in 0.02f..0.98f) {
        stroke.shader = null
        stroke.strokeWidth = 2 * dp
        stroke.color = hot
        stroke.alpha = (150 * (1f - bloomed)).roundToInt()
        canvas.drawCircle(fx, fy, radius - feather * 0.5f, stroke)
      }
      drawMotes(canvas, time, fx, fy, reach = 44 * dp, lit = bloomed)
      // The flame flares, lights the room, then gutters out.
      val flare = if (progress < 0.25f) sin(progress / 0.25f * PI.toFloat()) else 0f
      drawFlame(canvas, fx, fy, time, swell = flare, presence = (1f - (bloomed - 0.4f) * 1.8f).coerceIn(0f, 1f))
      drawMoth(canvas, fx, fy, time, flee = easeIn(progress))
    }
  }

  /** Darkness as overlapping breathing shadows, so there is no sheet with edges. */
  private fun drawShadows(
    canvas: Canvas,
    time: Float,
    alpha: Float,
  ) {
    val count = (width / (18 * dp)).roundToInt().coerceAtLeast(2)
    val slot = width / count
    for (i in 0 until count) {
      val cx = slot * (i + 0.5f) + slot * 0.15f * sin(time * 0.4f + i)
      val breathe = 1f + 0.08f * sin(time * 0.9f + i * 1.7f)
      // Wide enough to overlap into one bank, but the clouds at the ends fade before the edge,
      // so the slice's box never shows as a hard corner.
      val rx = minOf(slot * 2.2f * breathe, max(slot, cx), max(slot, width - cx))
      softEllipse(canvas, cx, height / 2, rx, height * 0.5f * breathe, shadow, 0.92f * alpha, core = 0.5f)
    }
  }

  private fun drawMotes(
    canvas: Canvas,
    time: Float,
    fx: Float,
    fy: Float,
    reach: Float,
    lit: Float,
  ) {
    motes.forEach { m ->
      val x = m.x + sin(time * 0.6f + m.phase) * 3 * dp
      val y = m.y + cos(time * 0.5f + m.phase) * 2 * dp
      val near = (1f - hypot(x - fx, y - fy) / reach).coerceAtLeast(0f)
      val a = max(lit, near) * (0.5f + 0.5f * sin(time * 3f + m.phase)) * 0.9f
      circle(canvas, x, y, m.size, warm, a)
    }
  }

  private fun drawFlame(
    canvas: Canvas,
    fx: Float,
    fy: Float,
    time: Float,
    swell: Float,
    presence: Float,
  ) {
    if (presence <= 0.01f) return
    val breath = 0.9f + 0.1f * sin(time * 2.2f) + 0.05f * sin(time * 13f)
    val halo = (30 * dp) * breath + swell * 30 * dp
    softEllipse(canvas, fx, fy, halo, height * 0.5f, warm, 0.55f * presence, core = 0.08f)
    softEllipse(canvas, fx, fy, halo * 0.35f, min(halo * 0.3f, height * 0.4f), hot, (0.7f + swell * 0.3f) * presence, core = 0.2f)
    // A thread of smoke rising off the tip.
    val h = height * 0.42f * breath
    path.reset()
    path.moveTo(fx, fy - h)
    for (k in 1..4) {
      val yy = fy - h - k * 3.5f * dp
      path.lineTo(fx + sin(time * 2.5f + k * 1.4f) * (1f + k * 0.8f) * dp, yy)
    }
    strokePath(canvas, path, 1f * dp, smoke, 0.3f * presence)
    // The flame itself: a teardrop leaning with the draught.
    val lean = sin(time * 5f) * 1.2f * dp
    flame.reset()
    flame.moveTo(fx, fy - h)
    flame.quadTo(fx + h * 0.55f + lean, fy - h * 0.2f, fx, fy + h * 0.45f)
    flame.quadTo(fx - h * 0.55f + lean, fy - h * 0.2f, fx, fy - h)
    flame.close()
    fillPath(canvas, flame, ember, presence)
    val saved = canvas.save()
    canvas.scale(0.55f, 0.6f, fx, fy + h * 0.1f)
    fillPath(canvas, flame, hot, presence)
    canvas.restoreToCount(saved)
  }

  /** A moth circling the flame; it flies off when the light floods the room. */
  private fun drawMoth(
    canvas: Canvas,
    fx: Float,
    fy: Float,
    time: Float,
    flee: Float,
  ) {
    if (flee >= 1f) return
    val r = 13 * dp
    val mx = fx + cos(time * 2.3f + wander) * r + flee * 60 * dp
    val my = fy + sin(time * 3.1f + wander) * r * 0.55f - flee * 70 * dp
    val flap = abs(sin(time * 22f))
    val s = 2.8f * dp
    val a = (1f - flee) * 0.9f
    circle(canvas, mx, my, s * 0.35f, moth, a)
    for (side in intArrayOf(-1, 1)) {
      path.reset()
      path.moveTo(mx, my)
      path.lineTo(mx + side * s * (0.5f + flap * 0.8f), my - s * 0.9f)
      path.lineTo(mx + side * s * (0.7f + flap), my + s * 0.2f)
      path.close()
      fillPath(canvas, path, moth, a * (0.5f + 0.5f * flap))
    }
  }
}
