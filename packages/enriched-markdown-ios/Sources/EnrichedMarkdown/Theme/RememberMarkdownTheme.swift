import SwiftUI

/// Re-create a `MarkdownTheme` when `colorScheme` or `dynamicTypeSize` changes.
///
/// Call from a `View.body` after reading those values from the environment:
///
/// ```swift
/// @Environment(\.colorScheme) private var colorScheme
/// @Environment(\.dynamicTypeSize) private var dynamicTypeSize
///
/// var body: some View {
///     let theme = rememberMarkdownTheme(colorScheme: colorScheme, dynamicTypeSize: dynamicTypeSize) {
///         Paragraph().foregroundStyle(.primary)
///     }
///     RootView()
///         .markdownTheme(theme)
/// }
/// ```
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
