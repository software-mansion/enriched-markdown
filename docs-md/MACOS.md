# macOS Support

`react-native-enriched-markdown` supports macOS via [react-native-macos](https://github.com/microsoft/react-native-macos). The native layer shares code with iOS through a platform abstraction header (`ENRMUIKit.h`), with macOS-specific implementations for context menus, text selection, and clipboard handling.

The macOS implementation supports the same rendering elements as iOS — CommonMark, GitHub Flavored Markdown (tables, task lists, strikethrough), images, code blocks, blockquotes, and all other supported elements. `EnrichedMarkdownTextInput` is also available on macOS with full support for inline styles, links, and the native context menu.

## Known limitations

These will be addressed in upcoming releases:

- **LaTeX math** (both inline and block) is not available on macOS. The math engine (RaTeX) is distributed as a Swift Package, which requires `use_frameworks!` in CocoaPods. `react-native-macos` does not currently support `use_frameworks!` due to circular dependencies between `React-Core` and `React-RCTText` ([microsoft/react-native-macos#1969](https://github.com/microsoft/react-native-macos/issues/1969)). Math will be enabled once this upstream issue is resolved.
- **Tail fade-in animation** falls back to instant reveal (no `CADisplayLink` on macOS)
- **VoiceOver** accessibility is stubbed (pending `NSAccessibility` implementation)
- **Font scale observation** does not respond to system font size changes
- **`selectionColor`** affects only the selection background. The iOS-style caret + handle tinting isn't available on macOS, since AppKit's `NSTextView` doesn't expose them via `tintColor`.

## Example app

See the [react-native-macos-example/](../apps/react-native-macos-example/) directory for a working example app.
