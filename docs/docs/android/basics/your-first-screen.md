---
sidebar_label: Your first markdown screen
sidebar_position: 2
---

# Your first markdown screen

With the library [installed](/android/basics/installation), let's get Markdown onto the screen. By the end of this page you'll have rendered your first document and restyled it.

## Rendering Markdown

`EnrichedMarkdownText` is a composable that takes a Markdown string and paints it as **fully native text** - no WebView, and no intermediate HTML. It parses with [md4c](https://github.com/mity/md4c) and renders through the platform's own text stack, so TalkBack and font scaling behave the way they do in any other `TextView`.

It is not one `TextView`, though. The document is split into **segments**: each run of ordinary blocks becomes one native text view, while each table - and each block a plugin draws, such as a math equation, or a code block set to [scroll horizontally](/android/api-reference/enriched-markdown-text#codeblocklayout) - gets a view of its own, stacked in document order. For a document without such blocks that is a single text view; when there are several, text selection stays within one segment.

Call it from any composable:

```kotlin
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.platform.LocalContext
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContent {
      MaterialTheme {
        val context = LocalContext.current

        EnrichedMarkdownText(
          markdown = "# Hello\n\nA paragraph with **bold** and a [link](https://swmansion.com).",
          onLinkClick = { url ->
            try {
              context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            } catch (e: ActivityNotFoundException) {
              // No app handles this URL - for example a relative link like "docs/intro.md".
            }
          },
        )
      }
    }
  }
}
```

That's the whole setup. With no style provided, the text renders with the built-in defaults, and links are inert until you give them a meaning - `onLinkClick` hands you the tapped URL and you decide what happens, here opening it in the browser. `onLinkClick` receives the URL exactly as written in the Markdown, so a relative link arrives without a scheme and no app will accept it; the `try` keeps that from crashing the app. The [`EnrichedMarkdownText` reference](/android/api-reference/enriched-markdown-text) covers the rest of the parameters and callbacks.

:::note
`EnrichedMarkdownText` renders nothing in `@Preview`. Previews run on your development machine, where the library's native parser cannot load, so there is no document to draw. Parsing and rendering also run on a background thread and land after the first frame, which a static preview never gets past. Use an emulator or a device. [Compose interop](/android/guides/compose-interop) has the details.
:::

## Styling it

Every element is styled through the `markdownStyle { }` DSL. Build a style once and hand it to `MarkdownTheme` as the default for a subtree:

```kotlin
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme
import com.swmansion.enriched.markdown.compose.markdownStyle

val AppMarkdownStyle = markdownStyle {
  paragraph {
    fontSize = 18.sp
    lineHeight = 30.sp
  }
  h1 {
    color = Color(0xFF7C3AED)
    fontWeight = FontWeight.Bold
  }
  link {
    color = Color(0xFF059669)
    textDecoration = TextDecoration.None
  }
}

@Composable
fun Article(markdown: String) {
  MarkdownTheme(style = AppMarkdownStyle) {
    EnrichedMarkdownText(markdown = markdown)
  }
}
```

The heading turns purple and bold, body text grows, and links turn green and lose their underline. Anything you don't set keeps its built-in default, so a style is a set of overrides rather than a full sheet you have to fill in.

Every `EnrichedMarkdownText` inside `MarkdownTheme` picks the style up. A single component can also take one through its `style` parameter, but that **replaces** the theme's style for that component rather than adding to it. To change a few properties on top of the theme, merge into it:

```kotlin
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme

@Composable
fun Caption(markdown: String) {
  EnrichedMarkdownText(
    markdown = markdown,
    style = MarkdownTheme.style.merge { paragraph { fontSize = 14.sp } },
  )
}
```

For the full list of blocks and the properties each one takes, see the [Style properties reference](/android/api-reference/style-properties); for how styles are provided, layered, and kept in sync with `MaterialTheme`, see [`MarkdownTheme`](/android/api-reference/markdown-theme).

## Editor on Android

There is no editor on Android **yet**: this package renders Markdown, it does not edit it. A rich text input for Android is on the [roadmap](/misc/roadmap).

## Next steps

You have a working screen. From here:

- [`EnrichedMarkdownText`](/android/api-reference/enriched-markdown-text) - every parameter and callback.
- [Parser extensions](/android/guides/parser-extensions) - turning on the syntax that is off by default, such as underline, super/subscript, and GitHub alerts.
- [`MarkdownTheme`](/android/api-reference/markdown-theme) - providing, layering, and theming styles.
- [Compose interop](/android/guides/compose-interop) - sizing, lists, selection, and previews.
- [Images and caching](/android/guides/image-caching) - where images can come from and how they are cached.
- [LaTeX math](/android/guides/latex-math) - rendering equations with the optional `math` artifact.
- [Code highlighting](/android/guides/code-highlighting) - coloring fenced code with the optional `code-highlight` artifact.
