import UIKit

public struct SpoilerStyle: Equatable, Sendable {
    /// Color of the particles or of the solid box.
    public var color: UIColor?
    /// Backdrop under the particles.
    public var backgroundColor: UIColor?
    public var particleDensity: CGFloat?
    public var particleSpeed: CGFloat?
    public var solidBorderRadius: CGFloat?

    public init(
        color: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        particleDensity: CGFloat? = nil,
        particleSpeed: CGFloat? = nil,
        solidBorderRadius: CGFloat? = nil
    ) {
        self.color = color
        self.backgroundColor = backgroundColor
        self.particleDensity = particleDensity
        self.particleSpeed = particleSpeed
        self.solidBorderRadius = solidBorderRadius
    }

    public mutating func merge(_ other: SpoilerStyle) {
        color = other.color ?? color
        backgroundColor = other.backgroundColor ?? backgroundColor
        particleDensity = other.particleDensity ?? particleDensity
        particleSpeed = other.particleSpeed ?? particleSpeed
        solidBorderRadius = other.solidBorderRadius ?? solidBorderRadius
    }
}
