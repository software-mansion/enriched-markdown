package swmansion.enriched.markdown.android.example

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.Md4cFlags
import com.swmansion.enriched.markdown.compose.material3.rememberMaterialMarkdownStyle

/**
 * Markdown styled by [rememberMaterialMarkdownStyle] under its own [MaterialTheme], with a switch
 * between the light and dark schemes. It starts in the system's mode.
 */
@Composable
fun MaterialThemeScreen(
  markdown: String,
  modifier: Modifier = Modifier,
) {
  val context = LocalContext.current
  val systemDark = isSystemInDarkTheme()
  var dark by rememberSaveable { mutableStateOf(systemDark) }
  val colorScheme = remember(dark) { if (dark) darkColorScheme() else lightColorScheme() }

  MaterialTheme(colorScheme = colorScheme) {
    Surface(modifier = modifier.fillMaxSize()) {
      Column {
        Row(
          modifier =
            Modifier
              .fillMaxWidth()
              .padding(horizontal = 16.dp, vertical = 8.dp),
          horizontalArrangement = Arrangement.SpaceBetween,
          verticalAlignment = Alignment.CenterVertically,
        ) {
          Text("Dark mode", style = MaterialTheme.typography.titleMedium)
          Switch(checked = dark, onCheckedChange = { dark = it })
        }
        HorizontalDivider()
        Column(
          modifier =
            Modifier
              .fillMaxSize()
              .verticalScroll(rememberScrollState())
              .padding(16.dp),
        ) {
          EnrichedMarkdownText(
            markdown = markdown,
            modifier = Modifier.fillMaxWidth(),
            style = rememberMaterialMarkdownStyle(),
            flags = Md4cFlags(highlight = true, admonitions = true),
            onLinkClick = { url ->
              runCatching {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
              }
            },
          )
        }
      }
    }
  }
}
