package swmansion.enriched.markdown.android.example

import android.graphics.BitmapFactory
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.MutableTransitionState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SuggestionChip
import androidx.compose.material3.SuggestionChipDefaults
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.input.pointer.PointerEventPass
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.LayoutCoordinates
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.Md4cFlags
import com.swmansion.enriched.markdown.TaskListItemPressEvent
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private val GUTTER = 20.dp

/** Margin the tour leaves above a card it has scrolled to. */
private val TOUR_LEAD = 14.dp
private const val COLOPHON_ID = "colophon"
private const val TRIPLE_TAP_WINDOW_MILLIS = 600L

/** How long a checkbox notice stays up before it slides away. */
private const val NOTICE_MILLIS = 1_100L

/** Parser extensions every card renders with; the sources rely on all four. */
private val RENDER_FLAGS =
  Md4cFlags(
    underline = true,
    superscript = true,
    subscript = true,
    admonitions = true,
  )

/**
 * The release's additions to the Android renderer, one card each: the feature,
 * the markdown that exercises it, and the live render of that markdown —
 * short enough to scroll in one take, and most of it answers a tap.
 *
 * Material 3 on an off-white ground, bookended by two navy blocks — the
 * masthead and the colophon — so it reads as the renderer's launch page,
 * not another sample. The screen owns its top bar so it can dress it to
 * match, and a checkbox tap is acknowledged by a brief pill near the
 * bottom edge that leaves on its own.
 *
 * A triple tap anywhere starts a guided tour for recording: the page glides
 * from card to card, resting on each for its dwell, longest on tables so the
 * grid can be dragged, then visits the colophon and eases back to the top.
 * A second triple tap stops it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WhatsNewScreen(
  onBack: () -> Unit,
  modifier: Modifier = Modifier,
) {
  val features = whatsNewFeatures
  val scrollState = rememberScrollState()
  val scrollBehavior = TopAppBarDefaults.pinnedScrollBehavior()
  var notice by remember { mutableStateOf<TaskNotice?>(null) }
  val scope = rememberCoroutineScope()

  // Where each block sits in the scrolled column, for the tour.
  var columnCoordinates by remember { mutableStateOf<LayoutCoordinates?>(null) }
  val blockCoordinates = remember { mutableMapOf<String, LayoutCoordinates>() }
  var tour by remember { mutableStateOf<Job?>(null) }
  val leadPx = with(LocalDensity.current) { TOUR_LEAD.roundToPx() }

  LaunchedEffect(notice) {
    if (notice == null) return@LaunchedEffect
    delay(NOTICE_MILLIS)
    notice = null
  }

  suspend fun glide(
    id: String,
    durationMillis: Int = 900,
  ) {
    val column = columnCoordinates ?: return
    val block = blockCoordinates[id] ?: return
    val top = column.localPositionOf(block, Offset.Zero).y.roundToInt() - leadPx
    scrollState.animateScrollTo(
      top.coerceIn(0, scrollState.maxValue),
      tween(durationMillis, easing = FastOutSlowInEasing),
    )
  }

  fun toggleTour() {
    val running = tour
    if (running != null) {
      running.cancel()
      tour = null
      return
    }
    tour =
      scope.launch {
        for (feature in features) {
          glide(feature.id)
          delay(feature.dwellMillis)
        }
        scrollState.animateScrollTo(scrollState.maxValue, tween(900, easing = FastOutSlowInEasing))
        delay(3_000)
        scrollState.animateScrollTo(0, tween(1_200, easing = FastOutSlowInEasing))
        tour = null
      }
  }

  MaterialTheme(colorScheme = WhatsNewColorScheme, typography = WhatsNewTypography) {
    Scaffold(
      modifier =
        modifier
          .fillMaxSize()
          .nestedScroll(scrollBehavior.nestedScrollConnection)
          .semantics { testTagsAsResourceId = true }
          .testTag("whats-new-screen"),
      containerColor = WhatsNewPalette.ground,
      topBar = {
        TopAppBar(
          title = { Text("What's New") },
          navigationIcon = {
            IconButton(onClick = onBack) {
              Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
            }
          },
          colors =
            TopAppBarDefaults.topAppBarColors(
              containerColor = WhatsNewPalette.ground,
              scrolledContainerColor = WhatsNewPalette.card,
              titleContentColor = WhatsNewPalette.ink,
              navigationIconContentColor = WhatsNewPalette.accent,
            ),
          scrollBehavior = scrollBehavior,
        )
      },
    ) { innerPadding ->
      Box(
        modifier =
          Modifier
            .fillMaxSize()
            .padding(innerPadding),
      ) {
      Column(
        modifier =
          Modifier
            .fillMaxSize()
            .verticalScroll(scrollState)
            .onTripleTap { toggleTour() }
            .onGloballyPositioned { columnCoordinates = it }
            .padding(horizontal = GUTTER),
      ) {
        Reveal(order = 0, modifier = Modifier.padding(top = 6.dp)) {
          Masthead()
        }

        features.forEachIndexed { index, feature ->
          Reveal(
            order = index + 1,
            modifier =
              Modifier
                .padding(top = 16.dp)
                .onGloballyPositioned { blockCoordinates[feature.id] = it },
          ) {
            WhatsNewCard(
              index = index + 1,
              feature = feature,
              onTaskToggled = { event -> notice = TaskNotice(event) },
            )
          }
        }

        Colophon(
          modifier =
            Modifier
              .padding(top = 28.dp, bottom = 48.dp)
              .onGloballyPositioned { blockCoordinates[COLOPHON_ID] = it },
        )
      }

      TaskNoticePill(
        notice = notice,
        modifier =
          Modifier
            .align(Alignment.BottomCenter)
            .padding(bottom = 28.dp),
      )
      }
    }
  }
}

/** One checkbox toggle, keyed so two taps on the same item still re-announce. */
private data class TaskNotice(
  val event: TaskListItemPressEvent,
  val stamp: Long = System.nanoTime(),
)

/**
 * A navy pill that rises from the bottom edge to acknowledge a checkbox tap
 * and slides away after [NOTICE_MILLIS]. The last notice is kept while the
 * exit plays so the text does not vanish mid-animation.
 */
@Composable
private fun TaskNoticePill(
  notice: TaskNotice?,
  modifier: Modifier = Modifier,
) {
  var shown by remember { mutableStateOf(notice) }
  if (notice != null) shown = notice
  val event = shown?.event ?: return

  AnimatedVisibility(
    visible = notice != null,
    modifier = modifier,
    enter = fadeIn(tween(180)) + slideInVertically(tween(220, easing = FastOutSlowInEasing)) { it / 2 },
    exit = fadeOut(tween(160)) + slideOutVertically(tween(200)) { it / 2 },
  ) {
    Surface(
      shape = CircleShape,
      color = MaterialTheme.colorScheme.primary,
      contentColor = Color.White,
      shadowElevation = 8.dp,
    ) {
      Row(
        modifier = Modifier.padding(start = 12.dp, end = 18.dp, top = 10.dp, bottom = 10.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Surface(
          shape = CircleShape,
          color = if (event.checked) WhatsNewPalette.mint else Color.White.copy(alpha = 0.18f),
        ) {
          Icon(
            imageVector = if (event.checked) Icons.Filled.Check else Icons.Filled.Clear,
            contentDescription = null,
            tint = if (event.checked) WhatsNewPalette.accent else Color.White,
            modifier =
              Modifier
                .padding(4.dp)
                .size(14.dp),
          )
        }
        Text(
          text = (if (event.checked) "Done · " else "Undone · ") + event.text,
          style = MaterialTheme.typography.labelLarge,
          maxLines = 1,
          overflow = TextOverflow.Ellipsis,
        )
      }
    }
  }
}

/** Flat navy block: the page's one loud moment. */
@Composable
private fun Masthead() {
  NavyBlock {
    Column(
      modifier = Modifier.padding(24.dp),
      verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
      Surface(
        shape = CircleShape,
        color = MaterialTheme.colorScheme.primaryContainer,
      ) {
        Text(
          text = "ENRICHED MARKDOWN · ANDROID",
          style = MaterialTheme.typography.labelSmall,
          color = MaterialTheme.colorScheme.onPrimaryContainer,
          modifier = Modifier.padding(horizontal = 12.dp, vertical = 6.dp),
        )
      }

      Text(
        text = "Five new things markdown can do",
        style = MaterialTheme.typography.headlineMedium,
        color = Color.White,
      )

      Text(
        text =
          "GitHub tables and task lists, strikethrough, super- and subscript, and admonitions. " +
            "Plain markdown in, rendered live below its source.",
        style = MaterialTheme.typography.bodyLarge,
        color = WhatsNewPalette.mint.copy(alpha = 0.9f),
      )
    }
  }
}

@Composable
private fun Colophon(modifier: Modifier = Modifier) {
  val context = LocalContext.current
  val logo =
    remember {
      runCatching {
        context.assets.open("logo_icon.png").use { BitmapFactory.decodeStream(it) }
      }.getOrNull()?.asImageBitmap()
    }

  NavyBlock(modifier = modifier, cornerRadius = 22.dp) {
    Row(
      modifier = Modifier.padding(20.dp),
      horizontalArrangement = Arrangement.spacedBy(14.dp),
      verticalAlignment = Alignment.Top,
    ) {
      if (logo != null) {
        Surface(
          shape = RoundedCornerShape(9.dp),
          color = MaterialTheme.colorScheme.primaryContainer,
        ) {
          Image(
            bitmap = logo,
            contentDescription = null,
            modifier =
              Modifier
                .padding(6.dp)
                .size(24.dp),
          )
        }
      }

      Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Text(
          text = "ENRICHED MARKDOWN",
          style = MaterialTheme.typography.labelSmall,
          color = WhatsNewPalette.mint,
        )
        Text(
          text = "Markdown rendered natively in Jetpack Compose.",
          style = MaterialTheme.typography.bodySmall,
          color = Color.White.copy(alpha = 0.78f),
        )
      }
    }
  }
}

/** The masthead's and the colophon's ground: solid brand navy with a soft drop. */
@Composable
private fun NavyBlock(
  modifier: Modifier = Modifier,
  cornerRadius: Dp = 28.dp,
  content: @Composable () -> Unit,
) {
  Surface(
    modifier = modifier.fillMaxWidth(),
    shape = RoundedCornerShape(cornerRadius),
    color = MaterialTheme.colorScheme.primary,
    contentColor = Color.White,
    shadowElevation = 6.dp,
  ) {
    content()
  }
}

/**
 * One feature: numbered title, blurb, the markdown in a sunken block, and
 * the render beneath it with an interaction cue where there is one.
 */
@Composable
private fun WhatsNewCard(
  index: Int,
  feature: WhatsNewFeature,
  onTaskToggled: (TaskListItemPressEvent) -> Unit,
) {
  ElevatedCard(
    modifier = Modifier.fillMaxWidth(),
    shape = RoundedCornerShape(20.dp),
    colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
    elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp),
  ) {
    Column(
      modifier = Modifier.padding(18.dp),
      verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
      Row(
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
      ) {
        Surface(
          shape = RoundedCornerShape(10.dp),
          color = MaterialTheme.colorScheme.primaryContainer,
        ) {
          Text(
            text = "%02d".format(index),
            style = MaterialTheme.typography.labelLarge,
            color = MaterialTheme.colorScheme.onPrimaryContainer,
            textAlign = TextAlign.Center,
            modifier =
              Modifier
                .size(34.dp)
                .wrapContentSize(Alignment.Center),
          )
        }

        Text(
          text = feature.title,
          style = MaterialTheme.typography.titleLarge,
          color = MaterialTheme.colorScheme.onSurface,
        )
      }

      Text(
        text = feature.blurb,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
      )

      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionLabel("MARKDOWN")

        // The source, printed in a dark pane so the card visibly goes from
        // code to page. The pane is the library's own code block.
        EnrichedMarkdownText(
          markdown = "~~~markdown\n${feature.source}\n~~~",
          modifier = Modifier.fillMaxWidth(),
          style = WhatsNewSourceStyle,
          selectable = false,
        )
      }

      Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionLabel("RENDERED")

        EnrichedMarkdownText(
          markdown = feature.source,
          modifier = Modifier.fillMaxWidth(),
          style = WhatsNewMarkdownStyle,
          flags = RENDER_FLAGS,
          onTaskListItemPress = onTaskToggled,
        )

        if (feature.hint != null) {
          Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
          ) {
            SuggestionChip(
              onClick = {},
              label = { Text(feature.hint, style = MaterialTheme.typography.labelMedium) },
              colors =
                SuggestionChipDefaults.suggestionChipColors(
                  containerColor = MaterialTheme.colorScheme.primaryContainer,
                  labelColor = MaterialTheme.colorScheme.onPrimaryContainer,
                ),
              border = null,
            )
          }
        }
      }
    }
  }
}

@Composable
private fun SectionLabel(text: String) {
  Text(
    text = text,
    style = MaterialTheme.typography.labelSmall,
    color = MaterialTheme.colorScheme.onSurfaceVariant,
  )
}

/** Fades a block in and lifts it into place, `order` steps after the one before it. */
@Composable
private fun Reveal(
  order: Int,
  modifier: Modifier = Modifier,
  content: @Composable () -> Unit,
) {
  val visibility = remember { MutableTransitionState(false).apply { targetState = true } }
  val lift = with(LocalDensity.current) { 12.dp.roundToPx() }
  val spec = tween<Float>(durationMillis = 500, delayMillis = 70 * order)
  val offsetSpec = tween<IntOffset>(durationMillis = 500, delayMillis = 70 * order)

  AnimatedVisibility(
    visibleState = visibility,
    modifier = modifier,
    enter = fadeIn(spec) + slideInVertically(offsetSpec) { lift },
  ) {
    content()
  }
}

/**
 * Fires after three presses inside [TRIPLE_TAP_WINDOW_MILLIS]. Presses are
 * observed in the initial pass, so the markdown views underneath — which
 * consume their own touches for selection and links — cannot swallow them.
 */
private fun Modifier.onTripleTap(onTripleTap: () -> Unit): Modifier =
  pointerInput(Unit) {
    val presses = ArrayDeque<Long>()
    awaitPointerEventScope {
      while (true) {
        val event = awaitPointerEvent(PointerEventPass.Initial)
        if (event.type != PointerEventType.Press) continue
        val now = event.changes.first().uptimeMillis
        presses.addLast(now)
        while (presses.isNotEmpty() && now - presses.first() > TRIPLE_TAP_WINDOW_MILLIS) {
          presses.removeFirst()
        }
        if (presses.size >= 3) {
          presses.clear()
          onTripleTap()
        }
      }
    }
  }
