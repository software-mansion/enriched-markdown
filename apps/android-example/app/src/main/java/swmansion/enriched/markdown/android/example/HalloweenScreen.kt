package swmansion.enriched.markdown.android.example

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.Crossfade
import androidx.compose.animation.SizeTransform
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownOptions
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.markdownStyle
import com.swmansion.enriched.markdown.spoiler.SpoilerOverlay
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/** The rooms of the house, each with its own way of hiding the words. */
enum class Room(
  val title: String,
  val kicker: String,
  val tagline: String,
  val emoji: String,
  val accent: Color,
  val overlay: SpoilerOverlay,
) {
  Attic("Attic", "FIRST FLOOR · ROOM 1", "Spun over the words. The spider is in.", "🕸️", Color(0xFFCBD5E1), CobwebSpoiler()),
  Crypt("Crypt", "BELOW GROUND · ROOM 2", "A green mist, and something under it.", "🪦", Color(0xFF34D399), CryptFogSpoiler()),
  Porch("Porch", "FRONT OF HOUSE · ROOM 3", "A grin carved over every answer.", "🎃", Color(0xFFF97316), LanternSpoiler()),
  Nursery("Nursery", "SECOND FLOOR · ROOM 4", "Sheets that drift. Tap, and boo.", "👻", Color(0xFFE9E5FF), GhostSpoiler()),
  Belfry("Belfry", "THE TOWER · ROOM 5", "They roost on the words until you tap.", "🦇", Color(0xFFA78BFA), BatsSpoiler()),
  Kitchen("Kitchen", "GROUND FLOOR · ROOM 6", "Something dripped. It is still dripping.", "🔪", Color(0xFFEF4444), BloodSpoiler()),
  Cellar("Cellar", "BELOW STAIRS · ROOM 7", "One candle. Keep it lit.", "🕯️", Color(0xFFFBBF24), CandleSpoiler()),
  ;

  /** The line of the snippet that picks this room. */
  val snippet: String get() = "spoilerOverlay = ${overlay::class.simpleName}()"
}

private val Pirata = FontFamily(Font(R.font.pirata_one))
private val Fell = FontFamily(Font(R.font.im_fell_english))
private val FellItalic = FontFamily(Font(R.font.im_fell_english_italic))
private val FellSmallCaps = FontFamily(Font(R.font.im_fell_english_sc))
private val Mono = FontFamily(Font(R.font.courier_prime_regular))

private val Night = Color(0xFF0E0818)
private val NightDeep = Color(0xFF1B1030)
private val Page = Color(GUEST_BOOK_PAGE)
private val Cream = Color(0xFFF1E4C8)
private val CreamSoft = Color(0xFFB9AC95)
private val Gold = Color(0xFFC9A24A)
private val Pumpkin = Color(0xFFF97316)
private val Moon = Color(0xFFF3E9C9)

/** Guest book styling: an old serif on a dark page, headings in blackletter, the room's color on the rules. */
private fun guestBookStyle(room: Room): MarkdownStyle =
  markdownStyle {
    paragraph {
      fontFamily = Fell
      fontSize = 18.sp
      color = Cream
      lineHeight = 27.sp
      marginBottom = 12.dp
    }
    h2 {
      fontFamily = Pirata
      fontSize = 23.sp
      color = room.accent
      lineHeight = 30.sp
      marginBottom = 10.dp
    }
    strong {
      fontFamily = FellSmallCaps
      color = Color.White
    }
    emphasis {
      fontFamily = FellItalic
      color = CreamSoft
    }
    blockquote {
      fontFamily = FellItalic
      fontSize = 18.sp
      color = CreamSoft
      lineHeight = 27.sp
      // Clear, not the page color: overlays read the words' alpha for their glows.
      backgroundColor = Color.Transparent
      borderColor = room.accent
      borderWidth = 3.dp
      gapWidth = 14.dp
      marginBottom = 12.dp
    }
    // Ink on the page rather than chips: the room's name and the marked phrase in its color.
    code {
      fontFamily = Pirata
      fontSize = 19.sp
      color = room.accent
      backgroundColor = Color.Transparent
      borderColor = Color.Transparent
    }
    highlight {
      color = room.accent
      backgroundColor = Color.Transparent
    }
    strikethrough {
      color = CreamSoft
    }
    thematicBreak {
      color = Gold.copy(alpha = 0.55f)
      height = 1.dp
      marginTop = 4.dp
      marginBottom = 14.dp
    }
    spoiler {
      color = room.accent
    }
  }

/**
 * Seven custom spoiler overlays, one per room of a haunted house, over a page of its guest book.
 * The night behind the page has a moon, clouds, bats and fireflies; every tap of a room conceals
 * the page again.
 */
@Composable
fun HalloweenScreen(
  contentPadding: PaddingValues,
  modifier: Modifier = Modifier,
) {
  var room by rememberSaveable { mutableStateOf(Room.Attic) }
  // Bumped on every chip tap, so the page comes back concealed.
  var generation by rememberSaveable { mutableIntStateOf(0) }
  val haptics = LocalHapticFeedback.current

  Box(
    modifier =
      modifier
        .fillMaxSize()
        .semantics { testTagsAsResourceId = true }
        .testTag("halloween-screen"),
  ) {
    HauntedNight(room, Modifier.fillMaxSize())

    Column(
      modifier =
        Modifier
          .fillMaxSize()
          .verticalScroll(rememberScrollState())
          .padding(contentPadding)
          .padding(horizontal = 20.dp, vertical = 12.dp),
      verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
      Header(room)

      // Keeps the picked room in view, with its neighbour on the left showing there is more.
      val chips = rememberLazyListState()
      LaunchedEffect(room) { chips.animateScrollToItem((room.ordinal - 1).coerceAtLeast(0)) }
      LazyRow(
        state = chips,
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
      ) {
        items(Room.entries) { item ->
          RoomChip(
            room = item,
            selected = item == room,
            onClick = {
              room = item
              generation += 1
              haptics.performHapticFeedback(HapticFeedbackType.TextHandleMove)
            },
          )
        }
      }

      // The page swaps in place, its spoilers already hidden; only the header moves, as on iOS.
      GuestBookPage(room) {
        EnrichedMarkdownText(
          // Reveals carry over while the text is unchanged, so a repeated tap on the same room
          // alternates an invisible zero-width space to conceal the page again.
          markdown = HalloweenPages.markdown(room) + if (generation % 2 == 1) "\u200B" else "",
          modifier =
            Modifier
              .fillMaxWidth()
              .padding(horizontal = 22.dp, vertical = 18.dp),
          style = remember(room) { guestBookStyle(room) },
          options = MarkdownOptions(highlight = true),
          selectable = false,
          spoilerOverlay = room.overlay,
        )
      }

      Snippet(room)

      Text(
        text = "Please sign the book before you leave.",
        fontFamily = FellItalic,
        fontSize = 16.sp,
        color = Cream.copy(alpha = 0.7f),
        textAlign = TextAlign.Center,
        modifier =
          Modifier
            .fillMaxWidth()
            .padding(top = 4.dp),
      )
      Spacer(Modifier.height(8.dp))
    }
  }
}

@Composable
private fun Header(room: Room) {
  // The kicker and tagline cross-fade and the title rolls up, all on one spring.
  Column(Modifier.clipToBounds()) {
    Crossfade(room, animationSpec = RoomSpring, label = "kicker") { current ->
      Text(
        text = current.kicker,
        fontFamily = Fell,
        fontSize = 12.sp,
        letterSpacing = 3.sp,
        color = current.accent,
      )
    }
    AnimatedContent(
      targetState = room,
      transitionSpec = {
        (slideInVertically(spring(0.8f, 200f)) { it } + fadeIn(RoomSpring))
          .togetherWith(slideOutVertically(spring(0.8f, 200f)) { -it } + fadeOut(RoomSpring))
          .using(SizeTransform(clip = true))
      },
      label = "title",
    ) { current ->
      Text(
        text = "The ${current.title}",
        fontFamily = Pirata,
        fontSize = 42.sp,
        lineHeight = 46.sp,
        color = Cream,
        modifier = Modifier.padding(top = 2.dp),
      )
    }
    Crossfade(room, animationSpec = RoomSpring, label = "tagline") { current ->
      Text(
        text = current.tagline,
        fontFamily = FellItalic,
        fontSize = 17.sp,
        color = Cream.copy(alpha = 0.8f),
      )
    }
  }
}

@Composable
private fun RoomChip(
  room: Room,
  selected: Boolean,
  onClick: () -> Unit,
) {
  val fill by animateColorAsState(if (selected) Pumpkin else Color.White.copy(alpha = 0.08f), label = "chip-fill")
  Surface(
    onClick = onClick,
    shape = CircleShape,
    color = fill,
    border = if (selected) null else BorderStroke(1.dp, Gold.copy(alpha = 0.35f)),
    modifier = Modifier.testTag("room-${room.name.lowercase()}"),
  ) {
    Row(
      modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
      horizontalArrangement = Arrangement.spacedBy(6.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text(room.emoji, fontSize = 13.sp)
      Text(
        text = room.title,
        fontFamily = FellSmallCaps,
        fontSize = 14.sp,
        letterSpacing = 1.sp,
        color = if (selected) Night else Cream,
      )
    }
  }
}

/**
 * The guest book: a dark page with a gold double rule, a masthead, and the room's sign stamped
 * on the corner in wax.
 */
@Composable
private fun GuestBookPage(
  room: Room,
  content: @Composable () -> Unit,
) {
  val accent by animateColorAsState(room.accent, spring(0.8f, 200f), label = "page-accent")
  Box(Modifier.fillMaxWidth()) {
    Surface(
      modifier =
        Modifier
          .fillMaxWidth()
          .border(1.5.dp, Gold.copy(alpha = 0.7f), RoundedCornerShape(8.dp)),
      shape = RoundedCornerShape(8.dp),
      color = Page,
      shadowElevation = 18.dp,
    ) {
      Column(
        Modifier
          .padding(5.dp)
          .border(0.75.dp, Gold.copy(alpha = 0.45f), RoundedCornerShape(5.dp)),
      ) {
        Row(
          modifier =
            Modifier
              .fillMaxWidth()
              .background(Brush.verticalGradient(listOf(accent.copy(alpha = 0.18f), accent.copy(alpha = 0f))))
              // Room on the right for the seal on the corner.
              .padding(start = 22.dp, top = 12.dp, end = 64.dp, bottom = 10.dp),
          horizontalArrangement = Arrangement.SpaceBetween,
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text(
            text = "The Guest Book",
            fontFamily = FellSmallCaps,
            fontSize = 14.sp,
            letterSpacing = 3.sp,
            color = Gold,
          )
          Crossfade(room, animationSpec = RoomSpring, label = "page-number") { current ->
            Text(
              text = "No. ${current.ordinal + 1} · ${current.title.uppercase()}",
              fontFamily = Mono,
              fontSize = 11.sp,
              color = CreamSoft,
            )
          }
        }
        content()
      }
    }
    Box(
      modifier =
        Modifier
          .align(Alignment.TopEnd)
          .offset(x = 8.dp, y = (-12).dp)
          .shadow(8.dp, CircleShape)
          .background(Brush.radialGradient(listOf(Color(0xFF8B1A1A), Color(0xFF4A0A0E))), CircleShape)
          .border(1.5.dp, Gold.copy(alpha = 0.6f), CircleShape)
          .size(46.dp),
      contentAlignment = Alignment.Center,
    ) {
      Crossfade(room, animationSpec = RoomSpring, label = "seal") { current ->
        Text(current.emoji, fontSize = 22.sp)
      }
    }
  }
}

@Composable
private fun Snippet(room: Room) {
  Surface(
    shape = RoundedCornerShape(10.dp),
    color = Color.White.copy(alpha = 0.06f),
    border = BorderStroke(1.dp, Gold.copy(alpha = 0.25f)),
    modifier = Modifier.fillMaxWidth(),
  ) {
    Crossfade(room, animationSpec = RoomSpring, label = "snippet") { current ->
      Text(
        text = "EnrichedMarkdownText(\n  markdown,\n  ${current.snippet},\n)",
        fontFamily = FontFamily.Monospace,
        fontWeight = FontWeight.Medium,
        fontSize = 12.5.sp,
        lineHeight = 18.sp,
        color = Cream.copy(alpha = 0.92f),
        modifier = Modifier.padding(14.dp),
      )
    }
  }
}

/** The one spring every room change runs on, the same as the iOS Hogwarts screen's. */
private val RoomSpring = spring<Float>(dampingRatio = 0.8f, stiffness = 200f)

// The night

private const val TWO_PI = (2 * PI).toFloat()

/** Positions and timings for everything that drifts, flies or twinkles, drawn from one seed. */
private class NightThings(
  private val random: Random,
) {
  class Thing(val x: Float, val y: Float, val size: Float, val speed: Float, val phase: Float)

  private fun things(count: Int) = List(count) { Thing(random.nextFloat(), random.nextFloat(), random.nextFloat(), 0.6f + random.nextFloat() * 0.8f, random.nextFloat() * TWO_PI) }

  val stars = things(110)
  val clouds = things(5)
  val bats = things(7)
  val fireflies = things(16)
}

/**
 * The night behind the page: a gradient sky with stars, a full moon with clouds crossing it, bats
 * flying over, fireflies near the ground, the black silhouette of the house and its tree, and a
 * flicker of candlelight from below. The glow around the moon takes the room's color.
 */
@Composable
private fun HauntedNight(
  room: Room,
  modifier: Modifier = Modifier,
) {
  val tint by animateColorAsState(room.accent, tween(900), label = "night-tint")
  val things = remember { NightThings(Random(31101031)) }
  val bat = remember { Path() }
  val house = remember { Path() }

  var seconds by remember { mutableFloatStateOf(0f) }
  LaunchedEffect(Unit) {
    val start = withFrameNanos { it }
    while (true) withFrameNanos { seconds = (it - start) / 1_000_000_000f }
  }

  Canvas(modifier) {
    val t = seconds
    drawRect(Brush.verticalGradient(listOf(Night, NightDeep, Night)))
    things.stars.forEach { s ->
      val twinkle = (sin(t * 1.6f + s.phase) + 1f) / 2f
      drawCircle(Color.White, radius = (0.4f + s.size * 1.1f) * density, center = Offset(s.x * size.width, s.y * size.height * 0.8f), alpha = (0.25f + 0.6f * twinkle))
    }
    // The moon, with the room's color in its halo.
    val moon = Offset(size.width * 0.8f, size.height * 0.17f)
    val moonR = min(size.width, size.height) * 0.11f
    drawCircle(Brush.radialGradient(listOf(tint.copy(alpha = 0.32f), tint.copy(alpha = 0f)), moon, moonR * 3.2f), radius = moonR * 3.2f, center = moon, blendMode = BlendMode.Plus)
    drawCircle(Moon, radius = moonR, center = moon)
    drawCircle(Color(0xFFE1D4AE), radius = moonR * 0.18f, center = moon + Offset(-moonR * 0.3f, -moonR * 0.2f), alpha = 0.6f)
    drawCircle(Color(0xFFE1D4AE), radius = moonR * 0.11f, center = moon + Offset(moonR * 0.35f, moonR * 0.3f), alpha = 0.6f)
    drawCircle(Color(0xFFE1D4AE), radius = moonR * 0.08f, center = moon + Offset(moonR * 0.1f, moonR * 0.55f), alpha = 0.5f)
    things.clouds.forEachIndexed { i, c ->
      val x = ((c.x + t * 0.008f * c.speed) % 1.4f - 0.2f) * size.width
      val y = size.height * (0.08f + c.y * 0.22f)
      val w = size.width * (0.28f + c.size * 0.22f)
      drawSoftCloud(x, y, w, Color(0xFF2A1B45), 0.85f)
    }
    drawHouse(house)
    things.bats.forEachIndexed { i, b ->
      val x = ((b.x + t * (0.035f + b.speed * 0.02f)) % 1.3f - 0.15f) * size.width
      val y = size.height * (0.1f + b.y * 0.3f) + sin(t * 2.2f + b.phase) * size.height * 0.012f
      val flap = sin(t * (8f + b.speed * 3f) + b.phase)
      drawBat(bat, x, y, (9f + b.size * 7f) * density, flap)
    }
    things.fireflies.forEach { f ->
      val x = (f.x + sin(t * 0.3f + f.phase) * 0.03f) * size.width
      val y = size.height * (0.62f + f.y * 0.3f) + cos(t * 0.4f + f.phase) * size.height * 0.015f
      val glow = (sin(t * 1.8f + f.phase * 2) + 1f) / 2f
      drawCircle(Color(0xFFFFB347), radius = (1f + f.size) * density * (0.6f + glow), center = Offset(x, y), alpha = 0.25f + 0.65f * glow)
      drawCircle(Color(0xFFFFB347), radius = (4f + f.size * 3f) * density, center = Offset(x, y), alpha = 0.12f * glow)
    }
    // Candlelight from below, flickering.
    val flicker = 0.08f + 0.03f * sin(t * 9f) + 0.02f * sin(t * 23f)
    drawCircle(Brush.radialGradient(listOf(Color(0xFFFF8C42).copy(alpha = flicker), Color.Transparent), Offset(size.width * 0.5f, size.height * 1.05f), size.width * 0.75f), radius = size.width * 0.75f, center = Offset(size.width * 0.5f, size.height * 1.05f))
    // Ground fog.
    drawRect(Brush.verticalGradient(listOf(Color.Transparent, Color(0xFF8FBF9F).copy(alpha = 0.12f)), startY = size.height * 0.78f, endY = size.height))
  }
}

private fun DrawScope.drawSoftCloud(
  x: Float,
  y: Float,
  w: Float,
  color: Color,
  alpha: Float,
) {
  val h = w * 0.26f
  listOf(Offset(0f, 0f) to 1f, Offset(w * 0.28f, -h * 0.45f) to 0.6f, Offset(-w * 0.22f, -h * 0.25f) to 0.5f).forEach { (off, k) ->
    val cw = w * k
    val ch = h * (0.8f + k * 0.4f)
    drawOval(
      Brush.radialGradient(listOf(color.copy(alpha = alpha), color.copy(alpha = 0f)), Offset(x + off.x, y + off.y), cw / 2),
      topLeft = Offset(x + off.x - cw / 2, y + off.y - ch / 2),
      size = Size(cw, ch),
    )
  }
}

/** A bat in flight: body, ears and two scalloped wings; [flap] runs -1..1. */
private fun DrawScope.drawBat(
  p: Path,
  cx: Float,
  cy: Float,
  s: Float,
  flap: Float,
) {
  val lift = flap * s * 0.5f
  p.reset()
  p.moveTo(cx, cy - s * 0.45f)
  p.lineTo(cx - s * 0.18f, cy - s * 0.75f)
  p.lineTo(cx - s * 0.28f, cy - s * 0.35f)
  p.quadraticTo(cx - s * 0.9f, cy - s * 0.6f - lift, cx - s * 1.5f, cy - lift)
  p.quadraticTo(cx - s * 1.05f, cy + s * 0.05f - lift * 0.3f, cx - s * 0.8f, cy + s * 0.28f)
  p.quadraticTo(cx - s * 0.55f, cy + s * 0.05f, cx - s * 0.3f, cy + s * 0.32f)
  p.quadraticTo(cx, cy + s * 0.6f, cx + s * 0.3f, cy + s * 0.32f)
  p.quadraticTo(cx + s * 0.55f, cy + s * 0.05f, cx + s * 0.8f, cy + s * 0.28f)
  p.quadraticTo(cx + s * 1.05f, cy + s * 0.05f - lift * 0.3f, cx + s * 1.5f, cy - lift)
  p.quadraticTo(cx + s * 0.9f, cy - s * 0.6f - lift, cx + s * 0.28f, cy - s * 0.35f)
  p.lineTo(cx + s * 0.18f, cy - s * 0.75f)
  p.close()
  drawPath(p, Color(0xFF07040C), alpha = 0.95f)
}

/** The house on the hill and a bare tree, black against the sky along the bottom of the screen. */
private fun DrawScope.drawHouse(p: Path) {
  val w = size.width
  val h = size.height
  val ground = h * 0.9f
  p.reset()
  p.moveTo(0f, h)
  p.lineTo(0f, ground + h * 0.02f)
  p.quadraticTo(w * 0.12f, ground - h * 0.03f, w * 0.26f, ground)
  // The house: a body, a steep roof, a chimney and a small tower.
  p.lineTo(w * 0.3f, ground)
  p.lineTo(w * 0.3f, ground - h * 0.1f)
  p.lineTo(w * 0.33f, ground - h * 0.1f)
  p.lineTo(w * 0.33f, ground - h * 0.14f)
  p.lineTo(w * 0.35f, ground - h * 0.14f)
  p.lineTo(w * 0.35f, ground - h * 0.1f)
  p.lineTo(w * 0.42f, ground - h * 0.19f)
  p.lineTo(w * 0.49f, ground - h * 0.1f)
  p.lineTo(w * 0.52f, ground - h * 0.1f)
  p.lineTo(w * 0.52f, ground - h * 0.16f)
  p.lineTo(w * 0.545f, ground - h * 0.21f)
  p.lineTo(w * 0.57f, ground - h * 0.16f)
  p.lineTo(w * 0.57f, ground - h * 0.08f)
  p.lineTo(w * 0.6f, ground - h * 0.08f)
  p.lineTo(w * 0.6f, ground)
  p.quadraticTo(w * 0.8f, ground - h * 0.025f, w, ground + h * 0.01f)
  p.lineTo(w, h)
  p.close()
  drawPath(p, Color(0xFF07040C))
  // A lit window.
  drawRect(Color(0xFFFFB347), topLeft = Offset(w * 0.405f, ground - h * 0.075f), size = Size(w * 0.03f, h * 0.025f), alpha = 0.85f)
  // The tree: a trunk and branches reaching up.
  val tx = w * 0.82f
  val stroke = Stroke(width = 3.5f * density, cap = StrokeCap.Round)
  val thin = Stroke(width = 1.8f * density, cap = StrokeCap.Round)
  val bark = Color(0xFF07040C)
  p.reset()
  p.moveTo(tx, ground + h * 0.005f)
  p.quadraticTo(tx + w * 0.01f, ground - h * 0.08f, tx - w * 0.01f, ground - h * 0.15f)
  drawPath(p, bark, style = stroke)
  listOf(
    floatArrayOf(tx - w * 0.005f, ground - h * 0.1f, tx - w * 0.07f, ground - h * 0.17f, tx - w * 0.1f, ground - h * 0.16f),
    floatArrayOf(tx, ground - h * 0.12f, tx + w * 0.06f, ground - h * 0.19f, tx + w * 0.09f, ground - h * 0.185f),
    floatArrayOf(tx - w * 0.01f, ground - h * 0.15f, tx - w * 0.03f, ground - h * 0.22f, tx + w * 0.005f, ground - h * 0.24f),
    floatArrayOf(tx - w * 0.04f, ground - h * 0.145f, tx - w * 0.05f, ground - h * 0.19f, tx - w * 0.075f, ground - h * 0.2f),
  ).forEach { b ->
    p.reset()
    p.moveTo(b[0], b[1])
    p.quadraticTo(b[2], b[3], b[4], b[5])
    drawPath(p, bark, style = thin)
  }
}

