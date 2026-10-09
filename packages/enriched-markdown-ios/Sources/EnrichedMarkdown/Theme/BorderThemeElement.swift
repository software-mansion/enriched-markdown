import SwiftUI

/// An element drawn with a border whose color and width are set together,
/// as SwiftUI's `border(_:width:)` does.
public protocol BorderThemeElement: MarkdownThemeContent {
    var borderColorSpec: ThemeColorSpec? { get set }
    var borderWidth: CGFloat? { get set }
}

public extension BorderThemeElement {
    /// Sets the border color and, when given, its width; a nil width keeps
    /// the width a lower theme layer set.
    @_disfavoredOverload
    func border(_ color: Color, width: CGFloat? = nil) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: color)
        guard let width else { return copy }
        return copy.border(width: width)
    }

    func border(_ semantic: ThemeColorSpec.SemanticColor, width: CGFloat? = nil) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: semantic)
        guard let width else { return copy }
        return copy.border(width: width)
    }

    /// Sets only the width, keeping the color a lower layer set.
    func border(width: CGFloat) -> Self {
        var copy = self
        copy.borderWidth = width
        return copy
    }

    func applyBorder(color: inout UIColor?, width: inout CGFloat?, traitCollection: UITraitCollection) {
        if let borderColorSpec {
            color = borderColorSpec.resolve(traitCollection: traitCollection)
        }
        if let borderWidth { width = borderWidth }
    }
}
