import SwiftUI

private struct MarkdownSpoilerOverlayKey: EnvironmentKey {
    static let defaultValue: any SpoilerOverlayProvider = ParticleSpoilerOverlayProvider()
}

public extension EnvironmentValues {
    var markdownSpoilerOverlay: any SpoilerOverlayProvider {
        get { self[MarkdownSpoilerOverlayKey.self] }
        set { self[MarkdownSpoilerOverlayKey.self] = newValue }
    }
}

public extension View {
    /// Chooses the overlay that conceals spoiler text: `.particles` (the
    /// default), `.solid`, or a `SpoilerOverlayProvider` of your own. Colors
    /// and sizing of the built-ins come from the `Spoiler()` theme element.
    func markdownSpoilerOverlay(_ provider: any SpoilerOverlayProvider) -> some View {
        environment(\.markdownSpoilerOverlay, provider)
    }
}
