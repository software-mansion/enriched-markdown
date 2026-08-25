import SwiftUI

private struct MarkdownThemeLayersKey: EnvironmentKey {
    static let defaultValue: [MarkdownTheme] = [.default]
}

public extension EnvironmentValues {
    var markdownThemeLayers: [MarkdownTheme] {
        get { self[MarkdownThemeLayersKey.self] }
        set { self[MarkdownThemeLayersKey.self] = newValue }
    }
}

private struct MarkdownThemeLayerModifier: ViewModifier {
    @Environment(\.markdownThemeLayers) private var parentLayers
    let theme: MarkdownTheme

    func body(content: Content) -> some View {
        content.environment(\.markdownThemeLayers, parentLayers + [theme])
    }
}

public extension View {
    func markdownTheme(_ theme: MarkdownTheme) -> some View {
        modifier(MarkdownThemeLayerModifier(theme: theme))
    }

    func markdownTheme(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) -> some View {
        markdownTheme(MarkdownTheme(content: content()))
    }
}
