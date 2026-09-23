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

/// An animated particle field, the default. Colors come from the `Spoiler()`
/// theme element; the field's tuning is the provider's own.
public struct ParticleSpoilerOverlayProvider: SpoilerOverlayProvider {
    /// Particles per 100×100 pt; nil is 8.
    public var density: CGFloat?
    /// Drift in points per second; nil is 20.
    public var speed: CGFloat?

    public init(density: CGFloat? = nil, speed: CGFloat? = nil) {
        self.density = density
        self.speed = speed
    }

    public func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        ParticleSpoilerOverlayView(style: style, density: density, speed: speed, charRange: charRange)
    }
}

/// A solid rounded box in the `Spoiler()` theme color.
public struct SolidSpoilerOverlayProvider: SpoilerOverlayProvider {
    /// nil is 4.
    public var cornerRadius: CGFloat?

    public init(cornerRadius: CGFloat? = nil) {
        self.cornerRadius = cornerRadius
    }

    public func makeOverlay(charRange: NSRange, style: SpoilerStyle) -> SpoilerOverlayView {
        SolidSpoilerOverlayView(style: style, cornerRadius: cornerRadius, charRange: charRange)
    }
}

public extension SpoilerOverlayProvider where Self == ParticleSpoilerOverlayProvider {
    static var particles: Self { Self() }

    /// `.particles` with its own tuning: `.markdownSpoilerOverlay(.particles(density: 12, speed: 30))`.
    static func particles(density: CGFloat? = nil, speed: CGFloat? = nil) -> Self {
        Self(density: density, speed: speed)
    }
}

public extension SpoilerOverlayProvider where Self == SolidSpoilerOverlayProvider {
    static var solid: Self { Self() }

    /// `.solid` with its own corner radius: `.markdownSpoilerOverlay(.solid(cornerRadius: 6))`.
    static func solid(cornerRadius: CGFloat) -> Self {
        Self(cornerRadius: cornerRadius)
    }
}
