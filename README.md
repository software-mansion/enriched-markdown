<img src="https://github.com/user-attachments/assets/83cb462c-17df-4809-8b8a-fa4abb258cb3" alt="Enriched Markdown by Software Mansion" />

A multi-platform SDK for rendering Markdown as native text and editing rich text with Markdown output. Ships as a React Native library with iOS, Android, macOS, and Web support, plus standalone native SDKs for iOS (Swift) and Android (Kotlin).

## Features

- **Native text rendering** — High-performance Markdown rendering built on platform text APIs (no WebView)
- **Rich text input** — Text input with Markdown output, inline formatting, headings, lists, links, and mentions
- **Cross-platform** — Consistent API across React Native (TypeScript), iOS (Swift), and Android (Kotlin)
- **CommonMark & GFM** — Full CommonMark compliance with GitHub Flavored Markdown extensions (tables, task lists, strikethrough)
- **LaTeX math** — Block and inline math rendering powered by [RaTeX](https://github.com/erweixin/RaTeX)
- **Markdown streaming** — Real-time streaming support for AI/LLM chat interfaces
- **Code syntax highlighting** — Native syntax highlighting powered by [tree-sitter](https://tree-sitter.github.io/tree-sitter/)
- **Accessibility** — VoiceOver on iOS, TalkBack on Android, semantic HTML on web

See the [feature comparison table](https://enriched.swmansion.com/markdown) for a detailed breakdown of supported features per platform.

## Packages

| Platform | Package | Documentation |
|----------|---------|---------------|
| React Native | [![npm](https://img.shields.io/npm/v/react-native-enriched-markdown)](https://www.npmjs.com/package/react-native-enriched-markdown) | [React Native](https://enriched.swmansion.com/markdown) |
| Android | [![Maven Central](https://img.shields.io/maven-central/v/com.swmansion.enriched.markdown/ui)](https://central.sonatype.com/artifact/com.swmansion.enriched.markdown/ui) | [Android](https://enriched.swmansion.com/markdown) |
| iOS | *Coming soon* | [iOS](https://enriched.swmansion.com/markdown) |

Full documentation is available at the [documentation site](https://enriched.swmansion.com/markdown).

## Quick start

### React Native

```bash
yarn add react-native-enriched-markdown
```

```tsx
import { EnrichedMarkdownText } from 'react-native-enriched-markdown';
import { Linking } from 'react-native';

<EnrichedMarkdownText
  markdown={"# Hello\n\nThis is **enriched** [markdown](https://commonmark.org)."}
  onLinkPress={({ url }) => Linking.openURL(url)}
/>
```

### Android

```kotlin
dependencies {
  implementation("com.swmansion.enriched.markdown:compose:0.1.0")
}
```

```kotlin
import com.swmansion.enriched.markdown.compose.EnrichedMarkdownText
import com.swmansion.enriched.markdown.compose.MarkdownTheme

MarkdownTheme {
  EnrichedMarkdownText(
    markdown = "# Hello\n\nThis is **enriched** [markdown](https://commonmark.org).",
    onLinkPress = { url -> /* open url */ },
  )
}
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

Enriched Markdown is licensed under [The MIT License](./LICENSE).

---

Built by [Software Mansion](https://swmansion.com/).

[<img width="128" height="69" alt="Software Mansion Logo" src="https://github.com/user-attachments/assets/f0e18471-a7aa-4e80-86ac-87686a86fe56" />](https://swmansion.com/)
