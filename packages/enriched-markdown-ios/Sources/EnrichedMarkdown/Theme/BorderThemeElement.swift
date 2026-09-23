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
        if let width { copy.borderWidth = width }
        return copy
    }

    func border(_ semantic: ThemeColorSpec.SemanticColor, width: CGFloat? = nil) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: semantic)
        if let width { copy.borderWidth = width }
        return copy
    }

    func applyBorder(color: inout UIColor?, width: inout CGFloat?, traitCollection: UITraitCollection) {
        if let borderColorSpec {
            color = borderColorSpec.resolve(traitCollection: traitCollection)
        }
        if let borderWidth { width = borderWidth }
    }
}
