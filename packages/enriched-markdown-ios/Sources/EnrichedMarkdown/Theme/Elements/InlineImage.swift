import SwiftUI

public struct InlineImage: MarkdownThemeContent {
    public var size: CGFloat?

    public init() {}

    public func size(_ value: CGFloat) -> Self {
        var copy = self
        copy.size = value
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let size { config.inlineImage.size = size }
    }
}
