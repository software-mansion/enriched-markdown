import SwiftUI

public protocol BackgroundThemeElement: MarkdownThemeContent {
    var backgroundColorSpec: ThemeColorSpec? { get set }
}

public extension BackgroundThemeElement {
    func backgroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.backgroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    func backgroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.backgroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    func background(_ color: Color) -> Self {
        backgroundStyle(color)
    }

    func background(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        backgroundStyle(semantic)
    }

    func applyBackgroundColor(to color: inout UIColor?, traitCollection: UITraitCollection) {
        if let backgroundColorSpec {
            color = backgroundColorSpec.resolve(traitCollection: traitCollection)
        }
    }
}
