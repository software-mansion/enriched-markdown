<picture>
  <source media="(prefers-color-scheme: dark)" srcset="https://github.com/user-attachments/assets/38c4b0b7-4e2c-453a-bdd5-38d37dd6da46">
  <source media="(prefers-color-scheme: light)" srcset="https://github.com/user-attachments/assets/8793fe2a-b1a8-4bce-b2c3-26756899bd45">
  <img alt="Enriched Markdown by Software Mansion" src="https://github.com/user-attachments/assets/38c4b0b7-4e2c-453a-bdd5-38d37dd6da46">
</picture>

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

See the [feature comparison table](https://enriched.swmansion.com/markdown/#compatibility) for a detailed breakdown of supported features per platform.

## Packages

| Platform | Package | README |
|----------|---------|--------|
| React Native | [![npm](https://img.shields.io/npm/v/react-native-enriched-markdown)](https://www.npmjs.com/package/react-native-enriched-markdown) | [React Native](./packages/react-native-enriched-markdown/README.md) |
| Android | [![Maven Central](https://img.shields.io/maven-central/v/com.swmansion.enriched.markdown/ui)](https://central.sonatype.com/artifact/com.swmansion.enriched.markdown/ui) | [Android](./packages/android-enriched-markdown/README.md) |
| iOS | [![swift package](https://img.shields.io/github/v/tag/software-mansion-labs/enriched-markdown-ios?label=swift%20package)](https://github.com/software-mansion-labs/enriched-markdown-ios) | [iOS](./packages/enriched-markdown-ios/README.md) |


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

### iOS

```swift
dependencies: [
  .package(
    url: "https://github.com/software-mansion-labs/enriched-markdown-ios.git",
    from: "0.1.0"
  ),
]
```

```swift
import EnrichedMarkdown
import SwiftUI

EnrichedMarkdownText("# Hello\n\nThis is **enriched** [markdown](https://commonmark.org).")
  .onLinkPress { url in
    UIApplication.shared.open(url)
  }
```

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

Enriched Markdown is licensed under [The MIT License](./LICENSE).

---

Built by [Software Mansion](https://swmansion.com/).

[<img width="128" height="69" alt="Software Mansion Logo" src="https://github.com/user-attachments/assets/f0e18471-a7aa-4e80-86ac-87686a86fe56" />](https://swmansion.com/)
