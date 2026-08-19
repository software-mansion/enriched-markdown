import SwiftUI

public struct BlockImage: MarkdownThemeContent {
    public var height: CGFloat?
    public var borderRadius: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init() {}

    public func height(_ value: CGFloat) -> Self {
        var copy = self
        copy.height = value
        return copy
    }

    public func borderRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.borderRadius = value
        return copy
    }

    public func marginTop(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginTop = value
        return copy
    }

    public func marginBottom(_ value: CGFloat) -> Self {
        var copy = self
        copy.marginBottom = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let height { config.image.height = height }
        if let borderRadius { config.image.borderRadius = borderRadius }
        if let marginTop { config.image.marginTop = marginTop }
        if let marginBottom { config.image.marginBottom = marginBottom }
    }
}
