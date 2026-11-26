import SwiftUI

public protocol CornerRadiusThemeElement: MarkdownThemeContent {
    var cornerRadius: CGFloat? { get set }
}

public extension CornerRadiusThemeElement {
    func cornerRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.cornerRadius = value
        return copy
    }

    func applyCornerRadius(to radius: inout CGFloat?) {
        if let cornerRadius { radius = cornerRadius }
    }
}
