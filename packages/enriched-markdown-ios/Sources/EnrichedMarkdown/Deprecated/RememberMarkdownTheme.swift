import SwiftUI

// A Compose idiom that never did anything in SwiftUI: both parameters were
// discarded. Delete this file when the shim is removed.

/// Builds a `MarkdownTheme`; the two parameters are ignored.
@available(
    *, deprecated,
    message: "Build the theme with MarkdownTheme { } in body; SwiftUI re-evaluates it when colorScheme or dynamicTypeSize change."
)
@MainActor
public func rememberMarkdownTheme(
    colorScheme: ColorScheme,
    dynamicTypeSize: DynamicTypeSize,
    @MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup
) -> MarkdownTheme {
    _ = colorScheme
    _ = dynamicTypeSize
    return MarkdownTheme(content: content())
}
