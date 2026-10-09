package swmansion.enriched.markdown.android.example

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private data class HomeMenuItem(
  val route: ExampleRoute,
  val label: String,
  val subtext: String,
  val color: Color,
  val testTag: String,
)

private val menuItems =
  listOf(
    HomeMenuItem(ExampleRoute.Playground, "Playground", "live editor with preview", Color(0xFF007AFF), "home-block-playground"),
    HomeMenuItem(ExampleRoute.Text, "Text", "static markdown rendering", Color(0xFF34C759), "home-block-text"),
    HomeMenuItem(ExampleRoute.Input, "Input", "chat-style rich text input", Color(0xFFFF9500), "home-block-input"),
    HomeMenuItem(ExampleRoute.Stream, "Stream", "streaming markdown with tables", Color(0xFFAF52DE), "home-block-stream"),
    HomeMenuItem(ExampleRoute.Storybook, "Storybook", "component stories", Color(0xFFFF2D55), "home-block-storybook"),
  )

@Composable
fun HomeScreen(
  onNavigate: (ExampleRoute) -> Unit,
  modifier: Modifier = Modifier,
) {
  Column(
    modifier =
      modifier
        .fillMaxSize()
        .semantics { testTagsAsResourceId = true }
        .background(Color(0xFFF5F5F5))
        .verticalScroll(rememberScrollState())
        .padding(20.dp)
        .testTag("home-screen"),
    horizontalAlignment = Alignment.CenterHorizontally,
    verticalArrangement = Arrangement.Center,
  ) {
    Text(
      text = "Enriched Markdown Examples",
      fontSize = 28.sp,
      fontWeight = FontWeight.Bold,
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(bottom = 10.dp),
    )
    Text(
      text = "Explore different markdown rendering and input capabilities",
      fontSize = 16.sp,
      color = Color(0xFF666666),
      textAlign = TextAlign.Center,
      modifier = Modifier.padding(bottom = 40.dp),
    )

    menuItems.forEach { item ->
      HomeScreenButton(
        label = item.label,
        subtext = item.subtext,
        color = item.color,
        testTag = item.testTag,
        onClick = { onNavigate(item.route) },
        modifier = Modifier.fillMaxWidth(0.85f),
      )
    }
  }
}
