import SwiftUI

/// How `||spoiler||` text is concealed until tapped.
public enum MarkdownSpoilerOverlay: Equatable, Sendable {
    /// An animated particle field, the default.
    case particles
    /// A solid rounded box.
    case solid
}

private struct MarkdownSpoilerOverlayKey: EnvironmentKey {
    static let defaultValue: MarkdownSpoilerOverlay = .particles
}

public extension EnvironmentValues {
    var markdownSpoilerOverlay: MarkdownSpoilerOverlay {
        get { self[MarkdownSpoilerOverlayKey.self] }
        set { self[MarkdownSpoilerOverlayKey.self] = newValue }
    }
}

public extension View {
    /// Chooses the overlay that conceals spoiler text. Colors and sizing
    /// come from the `Spoiler()` theme element.
    func markdownSpoilerOverlay(_ overlay: MarkdownSpoilerOverlay) -> some View {
        environment(\.markdownSpoilerOverlay, overlay)
    }
}
