<img src="https://github.com/user-attachments/assets/83cb462c-17df-4809-8b8a-fa4abb258cb3" alt="react-native-enriched-markdown by Software Mansion" width="100%">
<a href="https://swm-delivery.com/www/delivery/ck-slug.php?zoneid=zone-gh-react-native-enriched-1&n=1"><img src="https://swm-delivery.com/www/images/zone-gh-react-native-enriched-1?n=1" /></a>
<a href="https://swm-delivery.com/www/delivery/ck-slug.php?zoneid=zone-gh-react-native-enriched-2&n=1"><img src="https://swm-delivery.com/www/images/zone-gh-react-native-enriched-2?n=1" /></a>
<a href="https://swm-delivery.com/www/delivery/ck-slug.php?zoneid=zone-gh-react-native-enriched-3&n=1"><img src="https://swm-delivery.com/www/images/zone-gh-react-native-enriched-3?n=1" /></a>

# react-native-enriched-markdown

`react-native-enriched-markdown` is a powerful React Native library that renders Markdown content as native text and provides a rich text input with Markdown output. It supports iOS, Android, macOS, and Web, and requires the New Architecture (Fabric) for native platforms.

### EnrichedMarkdownText

- ⚡ Fully native text rendering (no WebView)
- 🌐 Web support via [react-native-web](https://necolas.github.io/react-native-web/) + [md4c](https://github.com/mity/md4c) compiled to WebAssembly
- 🎯 High-performance Markdown parsing with [md4c](https://github.com/mity/md4c)
- 📐 CommonMark standard compliant
- 📊 GitHub Flavored Markdown (GFM)
- 🧮 LaTeX math rendering (block `$$...$$` with `flavor="github"`, inline `$...$` in all flavors)
- 🔀 [Markdown Streaming](docs/MARKDOWN_STREAMING.md) support (via [react-native-streamdown](https://github.com/software-mansion-labs/react-native-streamdown))
- 🎨 Fully customizable styles for all elements
- ✨ Text selection and copy support
- 📌 Custom text selection context menu items
- 🔗 Interactive link handling with [per-URL-pattern styling](docs/MENTIONS.md#link-variants-styling) (`linkVariants`)
- 👤 Renders mentions as styled links (compatible with `EnrichedMarkdownTextInput` mention output)
- 🙈 Spoiler text with animated particle overlay and tap-to-reveal
- 🖼️ Native image interactions (iOS: Copy, Save to Camera Roll)
- 🌐 Native platform features (Translate, Look Up, Search Web, Share)
- 🗣️ Accessibility support (VoiceOver on iOS, TalkBack on Android, semantic HTML on web)
- 🔄 Full RTL (right-to-left) support including text, lists, blockquotes, tables, and task lists

### EnrichedMarkdownTextInput

- ✏️ Rich text input with Markdown output
- 🕹️ Imperative API for toggling styles and managing links
- 📋 Native context menu with formatting submenu
- 🔍 Real-time style state detection
- 🔗 Auto-link detection with customizable regex
- 🔄 Smart copy/paste with Markdown preservation
- 🎨 Customizable bold, italic, and link colors
- 👤 [Mentions](docs/MENTIONS.md) with configurable indicators, suggestion lifecycle events, and per-pattern link styling

Since 2012 [Software Mansion](https://swmansion.com) is a software agency with experience in building web and mobile apps. We are Core React Native Contributors and experts in dealing with all kinds of React Native issues.
We can help you build your next dream product –
[Hire us](https://swmansion.com/contact/projects?utm_source=react-native-enriched-markdown&utm_medium=readme).

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [EnrichedMarkdownText](#enrichedmarkdowntext-1)
  - [Usage](docs/TEXT.md#usage)
  - [Supported Markdown Elements](docs/TEXT.md#supported-markdown-elements)
  - [Copy Options](docs/TEXT.md#copy-options)
  - [Accessibility](docs/TEXT.md#accessibility)
  - [RTL Support](docs/TEXT.md#rtl-support)
  - [Customizing Styles](docs/TEXT.md#customizing-styles)
  - [LaTeX Math](docs/LATEX_MATH.md)
  - [Image Caching](docs/IMAGE_CACHING.md)
  - [Markdown Streaming](docs/MARKDOWN_STREAMING.md)
- [EnrichedMarkdownTextInput](#enrichedmarkdowntextinput-1)
  - [Usage](docs/INPUT.md#usage)
  - [Inline Styles](docs/INPUT.md#inline-styles)
  - [Links](docs/INPUT.md#links)
  - [Auto-Link Detection](docs/INPUT.md#auto-link-detection)
  - [Mentions](docs/MENTIONS.md)
  - [Style Detection](docs/INPUT.md#style-detection)
  - [Other Events](docs/INPUT.md#other-events)
  - [Customizing Styles](docs/INPUT.md#customizing-enrichedmarkdowntextinput--styles)
- [API Reference](#api-reference)
- [Testing with Jest](docs/TESTING.md)
- [Web Support](docs/WEB.md)
- [macOS Support](docs/MACOS.md)
- [Compatibility Table](#compatibility-table)
- [Contributing](#contributing)
- [Future Plans](#future-plans)
- [License](#license)

## Prerequisites

**Native (iOS / Android / macOS)**

- Requires [the React Native New Architecture (Fabric)](https://reactnative.dev/architecture/landing-page)
- See [Compatibility Table](#compatibility-table) for supported React Native versions
- macOS support via [react-native-macos](https://github.com/microsoft/react-native-macos) `0.81+`

**Web**

- Requires [`react-native-web`](https://necolas.github.io/react-native-web/) and Metro (or another bundler with `.web.tsx` platform resolution)
- No New Architecture requirement — the web renderer runs entirely in JavaScript via WebAssembly
- Only `EnrichedMarkdownText` is supported on web (`EnrichedMarkdownTextInput` is native-only)
- LaTeX math requires the optional [`katex`](https://katex.org/) peer dependency

## Installation

### Web

No steps beyond having `react-native-web` configured. For LaTeX math, install the optional peer dependency:

```sh
npm install katex
# or
yarn add katex
```

See [Web Support](docs/WEB.md) for full setup details, supported features, and prop behaviour.

### Bare React Native app (iOS / Android)

#### 1. Install the library

```sh
yarn add react-native-enriched-markdown
```

> [!TIP]
> To try the latest features before they land in a stable release, install the nightly build:
>
> ```sh
> yarn add react-native-enriched-markdown@nightly
> ```
>
> Nightly versions are published to npm automatically and may contain breaking changes.

#### 2. Install iOS / macOS dependencies

The library includes native code so you will need to re-build the native app.

```sh
# iOS
cd ios && bundle install && bundle exec pod install

# macOS (react-native-macos)
cd macos && bundle install && bundle exec pod install
```

### Expo app

#### 1. Install the library

```sh
npx expo install react-native-enriched-markdown
```

#### 2. Run prebuild

The library includes native code so you will need to re-build the native app.

```sh
npx expo prebuild
```

> [!NOTE]
> The library won't work in Expo Go as it needs native changes.

> [!IMPORTANT]
> **iOS: Save to Camera Roll**
>
> If your Markdown content includes images and you want users to save them to their photo library, add the following to your `Info.plist`:
>
> ```xml
> <key>NSPhotoLibraryAddUsageDescription</key>
> <string>This app needs access to your photo library to save images.</string>
> ```

## EnrichedMarkdownText

See [EnrichedMarkdownText](docs/TEXT.md) for detailed documentation on usage examples, GFM tables, task lists, link handling, supported elements, copy options, accessibility, RTL support, and customizing styles. Mentions created by `EnrichedMarkdownTextInput` render as styled links — use [`linkVariants`](docs/MENTIONS.md#link-variants-styling) to customize their appearance.

## EnrichedMarkdownTextInput

See [EnrichedMarkdownTextInput](docs/INPUT.md) for detailed documentation on usage examples, inline styles, links, style detection, events, and customizing styles.

## API Reference

See the [API Reference](docs/API_REFERENCE.md) for a detailed overview of all the props, methods, and events available.

## Web Support

See [Web Support](docs/WEB.md) for details on supported features, web-specific prop behaviour, and known limitations.

## macOS Support

`react-native-enriched-markdown` supports macOS via [react-native-macos](https://github.com/microsoft/react-native-macos). See [macOS Support](docs/MACOS.md) for details on macOS-specific features, known limitations, and the example app.

## Future Plans

We're actively working on expanding the capabilities of `react-native-enriched-markdown`. Here's what's on the roadmap:

- `EnrichedMarkdownTextInput`: headings, lists, blockquotes, code blocks, inline images
- `EnrichedMarkdownTextInput` web support
- macOS: block math rendering, VoiceOver accessibility, tail fade-in animation
- Web: spoiler text, streaming animation, configurable link `target`, copy options (Copy as Markdown, multi-format clipboard)

## Compatibility Table

|             | 0.82 | 0.83 | 0.84 | 0.85 | 0.86 | 0.87 |
| ----------- | :--: | :--: | :--: | :--: | :--: | :--: |
| **nightly** |  ⛔  |  ✅  |  ✅  |  ✅  |  ✅  |  ✅  |
| **1.0.0**   |  ⛔  |  ✅  |  ✅  |  ✅  |  ✅  |  ✅  |
| **0.7.0**   |  ⛔  |  ✅  |  ✅  |  ✅  |  ✅  |  ✅  |
| **0.6.0**   |  ⛔  |  ✅  |  ✅  |  ✅  |  ⛔  |  ⛔  |
| **0.5.0**   |  ⛔  |  ✅  |  ✅  |  ✅  |  ⛔  |  ⛔  |
| **0.4.x**   |  ✅  |  ✅  |  ✅  |  ⛔  |  ⛔  |  ⛔  |
| **0.3.0**   |  ✅  |  ✅  |  ✅  |  ⛔  |  ⛔  |  ⛔  |

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

`react-native-enriched-markdown` library is licensed under [The MIT License](./LICENSE).

---

Built by [Software Mansion](https://swmansion.com/).

[<img width="128" height="69" alt="Software Mansion Logo" src="https://github.com/user-attachments/assets/f0e18471-a7aa-4e80-86ac-87686a86fe56" />](https://swmansion.com/)
