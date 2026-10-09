package swmansion.enriched.markdown.android.example

import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.swmansion.enriched.markdown.codehighlight.CodeHighlightPlugin
import com.swmansion.enriched.markdown.compose.MarkdownPlugins
import com.swmansion.enriched.markdown.math.LatexMathPlugin

class AndroidExampleMainActivity : ComponentActivity() {
  @OptIn(ExperimentalMaterial3Api::class)
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    enableEdgeToEdge()

    val sampleMarkdown =
      resources
        .openRawResource(R.raw.sample_markdown)
        .bufferedReader()
        .use { it.readText() }

    setContent {
      var currentRoute by rememberSaveable { mutableStateOf(ExampleRoute.Home) }

      MaterialTheme {
        // Math and code highlighting ship as their own artifacts; this scope enables both for every
        // EnrichedMarkdownText below. Math also needs `Md4cFlags(latexMath = true)` on the instance.
        MarkdownPlugins(LatexMathPlugin, CodeHighlightPlugin) {
          Scaffold(
            modifier = Modifier.fillMaxSize(),
            containerColor = Color.White,
            topBar = {
              TopAppBar(
                title = {
                  Text(
                    when (currentRoute) {
                      ExampleRoute.Home -> "Enriched Markdown Examples"
                      ExampleRoute.Playground -> "Playground"
                      ExampleRoute.Text -> "Text"
                      else -> currentRoute.name
                    },
                  )
                },
                navigationIcon = {
                  if (currentRoute != ExampleRoute.Home) {
                    TextButton(onClick = { currentRoute = ExampleRoute.Home }) {
                      Text("Back", color = Color(0xFF001A72))
                    }
                  }
                },
                colors =
                  TopAppBarDefaults.topAppBarColors(
                    containerColor = Color(0xFFBEEBD0),
                    titleContentColor = Color(0xFF001A72),
                    navigationIconContentColor = Color(0xFF001A72),
                  ),
              )
            },
          ) { innerPadding ->
            when (currentRoute) {
              ExampleRoute.Home ->
                HomeScreen(
                  modifier = Modifier.padding(innerPadding),
                  onNavigate = { route ->
                    when (route) {
                      ExampleRoute.Playground -> currentRoute = ExampleRoute.Playground
                      ExampleRoute.Text -> currentRoute = ExampleRoute.Text
                      else ->
                        Toast
                          .makeText(
                            this@AndroidExampleMainActivity,
                            "${route.name} is not available on Android yet",
                            Toast.LENGTH_SHORT,
                          ).show()
                    }
                  },
                )

              ExampleRoute.Playground ->
                PlaygroundScreen(
                  modifier = Modifier.padding(innerPadding),
                )

              ExampleRoute.Text ->
                TextScreen(
                  markdown = sampleMarkdown,
                  modifier = Modifier.padding(innerPadding),
                )

              else -> Unit
            }
          }
        }
      }
    }
  }
}
