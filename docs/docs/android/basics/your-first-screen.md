---
sidebar_label: Your first markdown screen
sidebar_position: 2
---

# Your first markdown screen

With the library [installed](/android/basics/installation), let's get Markdown onto the screen. By the end of this page you'll have rendered your first document and restyled it.

## Rendering Markdown

`EnrichedMarkdownText` is a composable that takes a Markdown string and paints it as **fully native text** - no WebView, and no intermediate HTML. It parses with [md4c](https://github.com/mity/md4c) and renders through the platform's own text stack, so selection, TalkBack, and font scaling behave the way they do in any other `TextView`.

Wrap your content in `MarkdownTheme` once, near the top of your UI, and render:

```kotlin
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.platform.LocalContext
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    setContent {
      MaterialTheme {
        MarkdownTheme {
          val context = LocalContext.current

          EnrichedMarkdownText(
            markdown = "# Hello\n\nA paragraph with **bold** and a [link](https://swmansion.com).",
            onLinkPress = { url ->
              context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
            },
          )
        }
      }
    }
  }
}
```

That's the whole setup. `MarkdownTheme` supplies the default style for everything beneath it, and links are inert until you give them a meaning - `onLinkPress` hands you the tapped URL and you decide what happens, here opening it in the browser. The [`EnrichedMarkdownText` reference](/android/api-reference/enriched-markdown-text) covers the rest of the parameters and callbacks.

:::note
`EnrichedMarkdownText` renders nothing in `@Preview`. It wraps a real Android `View`, which Compose previews do not run. Use an emulator or a device.
:::

## Styling it

Every element is styled through the `markdownStyle { }` DSL. Build a style once and hand it to `MarkdownTheme` as the default for the subtree, or pass one to a single component through its `style` parameter:

```kotlin
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.swmansion.enriched.markdown.compose.markdownStyle

val AppMarkdownStyle = markdownStyle {
  paragraph {
    fontSize = 16.sp
    lineHeight = 26.sp
    marginBottom = 16.dp
  }
  h1 { color = Color(0xFF111827) }
  link {
    color = Color(0xFF2563EB)
    underline = true
  }
}

MarkdownTheme(style = AppMarkdownStyle) {
  ArticleScreen()
}
```

Anything you don't set keeps its default, so a style is a set of overrides rather than a full sheet you have to fill in. For the full list of blocks and the properties each one takes, see the [Style properties reference](/android/api-reference/style-properties); for how styles are provided, layered, and kept in sync with `MaterialTheme`, see [`MarkdownTheme`](/android/api-reference/markdown-theme).

## Editor on Android

There is no editor on Android **yet**. `EnrichedMarkdownTextInput` - the live rich text input that the React Native package ships - has no Android counterpart today: this package renders Markdown, it does not edit it. Bringing the editor to the native packages is on the [roadmap](/misc/roadmap#the-editor-on-native).

## Next steps

You have a working screen. From here:

- [`EnrichedMarkdownText`](/android/api-reference/enriched-markdown-text) - every parameter and callback.
- [Parser extensions](/android/guides/parser-extensions) - turning on the syntax that is off by default, such as underline, super/subscript, and GitHub alerts.
- [Core concepts](/introduction/core-concepts) - the ideas behind the library.
- [Feature support](/introduction/supported-features) - what's supported on which platform.
