---
sidebar_label: macOS support
sidebar_position: 3
---

# macOS support

`react-native-enriched-markdown` supports macOS via [react-native-macos](https://github.com/microsoft/react-native-macos). The native layer shares code with iOS through a platform abstraction, with macOS-specific implementations for context menus, text selection, and clipboard handling.

macOS renders the same elements as iOS - CommonMark, GitHub Flavored Markdown (tables, task lists, strikethrough), images, code blocks, blockquotes, and the rest. `EnrichedMarkdownTextInput` is also available on macOS, with full support for inline styles, links, and the native context menu.

## Known limitations

These are expected to be addressed in upcoming releases:

- **LaTeX math** (inline and block) is not enabled on macOS yet. It is a possible future follow-up now that the math engine (RaTeX) ships as a vendored XCFramework with a macOS slice - see [LaTeX math](/rich-text-formatting/latex-math).
- **Tail fade-in animation** falls back to an instant reveal (no `CADisplayLink` on macOS).
- **VoiceOver** accessibility is stubbed, pending an `NSAccessibility` implementation - see [Accessibility](/misc/accessibility).
- **Font-scale observation** does not respond to system font-size changes.
- **`selectionColor`** affects only the selection background; the iOS-style caret and handle tinting is not available, since AppKit's `NSTextView` does not expose it via `tintColor`.
