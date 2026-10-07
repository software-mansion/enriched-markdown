package swmansion.enriched.markdown.android.example

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.testTagsAsResourceId
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownStyle
import com.swmansion.enriched.markdown.compose.invoke
import com.swmansion.enriched.markdown.syntaxhighlighting.SyntaxHighlightingPlugin
// `syntaxHighlighting` is an extension function shipped by the :syntax-highlighting artifact, not a
// member of the style builder, so it has to be imported before it can be used below.
import com.swmansion.enriched.markdown.syntaxhighlighting.compose.syntaxHighlighting

private const val CUSTOM_THEME_MARKDOWN = """## Custom token colors

A `syntaxHighlighting { }` block sets token colors; here, One Dark's. Any token it leaves unset keeps the default palette's color.

```javascript
// Debounce a handler by `wait` milliseconds
export function debounce(fn, wait = 200) {
  let timer = null;
  return (...args) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), wait);
  };
}
```
"""

private const val LIGHT_BLOCK_MARKDOWN = """## Light code blocks

With no token colors set, the palette follows the code block background: this light block gets GitHub's light palette.

```html
<nav class="toolbar" aria-label="Formatting">
  <!-- One button per inline style -->
  <button type="button" data-style="bold">B</button>
</nav>
```
"""

private val CustomThemeMarkdownStyle: MarkdownStyle =
  CustomMarkdownStyle.merge {
    codeBlock {
      color = Color(0xFFABB2BF)
      backgroundColor = Color(0xFF282C34)
      borderColor = Color(0xFF3E4451)
    }
    syntaxHighlighting {
      keyword = Color(0xFFC678DD)
      string = Color(0xFF98C379)
      number = Color(0xFFD19A66)
      constant = Color(0xFFD19A66)
      comment = Color(0xFF7F848E)
      function = Color(0xFF61AFEF)
      type = Color(0xFFE5C07B)
      property = Color(0xFFE06C75)
      tag = Color(0xFFE06C75)
      attribute = Color(0xFFD19A66)
      operator = Color(0xFF56B6C2)
    }
  }

private val LightCodeBlockMarkdownStyle: MarkdownStyle =
  CustomMarkdownStyle.merge {
    codeBlock {
      color = Color(0xFF1F2328)
      backgroundColor = Color(0xFFF6F8FA)
      borderColor = Color(0xFFD0D7DE)
    }
  }

@Composable
fun CodeScreen(modifier: Modifier = Modifier) {
  val context = LocalContext.current
  val markdown =
    remember {
      context.resources
        .openRawResource(R.raw.code_markdown)
        .bufferedReader()
        .use { it.readText() }
    }
  var highlightsSyntax by rememberSaveable { mutableStateOf(true) }

  Column(
    modifier =
      modifier
        .fillMaxSize()
        .semantics { testTagsAsResourceId = true }
        .background(Color.White)
        .verticalScroll(rememberScrollState())
        .padding(horizontal = 16.dp, vertical = 16.dp)
        .testTag("code-screen"),
  ) {
    Row(
      modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp),
      verticalAlignment = Alignment.CenterVertically,
    ) {
      Text("Syntax highlighting", fontSize = 16.sp, modifier = Modifier.weight(1f))
      Switch(
        checked = highlightsSyntax,
        onCheckedChange = { highlightsSyntax = it },
        modifier = Modifier.testTag("code-highlighting-toggle"),
      )
    }

    if (highlightsSyntax) {
      // Highlighting ships as its own artifact; this scope enables it for every EnrichedMarkdownText
      // below, on top of the math plugin the activity's scope already enables.
      SyntaxHighlightingPlugin {
        CodeSamples(markdown)
      }
    } else {
      CodeSamples(markdown)
    }
  }
}

@Composable
private fun CodeSamples(markdown: String) {
  EnrichedMarkdownText(
    markdown = markdown,
    modifier = Modifier.fillMaxWidth(),
    style = CustomMarkdownStyle,
  )
  EnrichedMarkdownText(
    markdown = CUSTOM_THEME_MARKDOWN,
    modifier = Modifier.fillMaxWidth(),
    style = CustomThemeMarkdownStyle,
  )
  EnrichedMarkdownText(
    markdown = LIGHT_BLOCK_MARKDOWN,
    modifier = Modifier.fillMaxWidth(),
    style = LightCodeBlockMarkdownStyle,
  )
}
