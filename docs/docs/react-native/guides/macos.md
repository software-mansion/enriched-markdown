---
sidebar_label: macOS support
sidebar_position: 7
---

# macOS support

`react-native-enriched-markdown` supports macOS via [react-native-macos](https://github.com/microsoft/react-native-macos). The native layer shares code with iOS through a platform abstraction, with macOS-specific implementations for context menus, text selection, and clipboard handling.

## Requirements

- **macOS 14.0** or newer (the podspec declares `:osx => '14.0'`).
- A `react-native-macos` project. The example app in this repository is built against `react-native-macos` 0.81, which trails the React Native versions listed on [Compatibility](/misc/compatibility).

## What works

macOS renders the same elements as iOS - CommonMark, GitHub Flavored Markdown (tables, task lists, strikethrough), images, code blocks, blockquotes, videos, spoilers, and the rest - with the exceptions below. `EnrichedMarkdownTextInput` is also available on macOS, with full support for inline styles, links, and the native context menu.

## Known limitations

Today, the macOS build differs from iOS in these ways. See [the roadmap](/misc/roadmap) for what is planned.

:::danger
**Block math (`$$...$$`) is silently dropped on macOS.** Under [`flavor="github"`](/react-native/api-reference/enriched-markdown-text#flavor) a display equation produces no segment and no fallback text, so the equation disappears from the output with nothing in its place. Inline `$...$` math renders correctly. If a document on macOS may contain display equations, either keep it on `flavor="commonmark"` (where the equation falls back to an inline attachment) or strip `$$` blocks before rendering.
:::

- **LaTeX math is unvalidated on macOS.** The math engine ([RaTeX](https://ratex.lites.dev/)) ships as a vendored XCFramework that does include a macOS slice, and there is no macOS gate in the podspec, so `enableMath` defaults to on and math compiles into a macOS app. Inline math has a working macOS render path; block math has the bug above. To opt out of the engine entirely, set `"enriched-markdown": { "enableMath": false }` in your app's `package.json` - see [Native assets](/react-native/guides/native-assets#optional-features).
- **Link pills** (`linkVariants[pattern].pill`, [`linkPillContent`](/react-native/api-reference/enriched-markdown-text#linkpillcontent)) are not rendered; such links appear as ordinary links with the variant's colors and font. See [Link pills](/react-native/guides/link-pills).
- **Tail fade-in animation** falls back to an instant reveal (there is no `CADisplayLink` on macOS). The content still appears; it just does not fade.
- **VoiceOver** accessibility is stubbed, pending an `NSAccessibility` implementation - see [Accessibility](/user-experience/accessibility).
- **Font-scale observation** does not respond to system font-size changes.
- **`selectionColor`** affects only the selection background; the iOS-style caret and handle tinting is not available, since AppKit's `NSTextView` does not expose it via `tintColor`.

## Props on macOS

The `@platform` annotations in the prop reference name iOS and Android, but the same iOS code runs on macOS, so most iOS-marked props apply there too. Two to know about explicitly:

- [`contextMenuItems`](/react-native/api-reference/enriched-markdown-text#contextmenuitems) **is** supported on macOS - custom items are prepended to the selection menu just as on iOS.
- [`streamingAnimation`](/react-native/api-reference/enriched-markdown-text#streaminganimation) is honored but degraded, per the fade-in limitation above.
- [`linkContextMenuItems`](/react-native/api-reference/enriched-markdown-text#linkcontextmenuitems) is **ignored** on macOS - it is an iOS 17+ feature. A long press on a link reaches `onLinkLongPress` instead; see [Link menus](/react-native/guides/link-menus).
