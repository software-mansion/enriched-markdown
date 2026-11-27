import EnrichedMarkdown
import SwiftUI

public struct SyntaxToken: MarkdownThemeContent {
    public let type: SyntaxTokenType
    public var foregroundColorSpec: ThemeColorSpec?

    public init(_ type: SyntaxTokenType) {
        self.type = type
    }

    @_disfavoredOverload
    public func foregroundStyle(_ color: Color) -> Self {
        var copy = self
        copy.foregroundColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func foregroundStyle(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.foregroundColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfiguration, traitCollection: UITraitCollection) {
        guard let foregroundColorSpec else { return }

        config.syntaxHighlight.colors[type] = foregroundColorSpec.resolve(traitCollection: traitCollection)
    }
}

public extension MarkdownTheme {
    /// GitHub's palette, light or dark with the color scheme.
    static let syntaxHighlightingDefault = MarkdownTheme {
        SyntaxToken(.keyword).foregroundStyle(light: 0xCF222E, dark: 0xFF7B72)
        SyntaxToken(.string).foregroundStyle(light: 0x0A3069, dark: 0xA5D6FF)
        SyntaxToken(.number).foregroundStyle(light: 0x0550AE, dark: 0x79C0FF)
        SyntaxToken(.constant).foregroundStyle(light: 0x0550AE, dark: 0x79C0FF)
        SyntaxToken(.comment).foregroundStyle(light: 0x6E7781, dark: 0x8B949E)
        SyntaxToken(.function).foregroundStyle(light: 0x8250DF, dark: 0xD2A8FF)
        SyntaxToken(.type).foregroundStyle(light: 0x953800, dark: 0xFFA657)
        SyntaxToken(.property).foregroundStyle(light: 0x0550AE, dark: 0x79C0FF)
        SyntaxToken(.tag).foregroundStyle(light: 0x116329, dark: 0x7EE787)
        SyntaxToken(.attribute).foregroundStyle(light: 0x0550AE, dark: 0x79C0FF)
    }
}

private extension SyntaxToken {
    func foregroundStyle(light: UInt32, dark: UInt32) -> Self {
        var copy = self
        copy.foregroundColorSpec = .uiColor(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
        return copy
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
