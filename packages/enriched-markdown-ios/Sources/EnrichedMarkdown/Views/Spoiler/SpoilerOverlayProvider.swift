import UIKit

/// Builds the views that conceal `||spoiler||` text; see `SpoilerOverlayView`
/// for the contract. A text view rebuilds its overlays only when the provider
/// value changes, so a parameterized provider should keep its parameters in
/// stored properties and let `Equatable` synthesis compare them.
public protocol SpoilerOverlayProvider: Equatable, Sendable {
    @MainActor
    func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView
}

extension SpoilerOverlayProvider {
    func isEqual(to other: any SpoilerOverlayProvider) -> Bool {
        guard let other = other as? Self else { return false }
        return self == other
    }
}

/// An animated particle field, the default.
public struct ParticleSpoilerOverlayProvider: SpoilerOverlayProvider {
    public init() {}

    public func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ParticleSpoilerOverlayView(style: style, charRange: charRange)
    }
}

/// A solid rounded box.
public struct SolidSpoilerOverlayProvider: SpoilerOverlayProvider {
    public init() {}

    public func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        SolidSpoilerOverlayView(style: style, charRange: charRange)
    }
}

public extension SpoilerOverlayProvider where Self == ParticleSpoilerOverlayProvider {
    static var particles: Self { Self() }
}

public extension SpoilerOverlayProvider where Self == SolidSpoilerOverlayProvider {
    static var solid: Self { Self() }
}
