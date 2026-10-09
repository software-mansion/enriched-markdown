import SwiftUI

// Shims for the 0.1 theme-element modifiers. Delete this file when they are
// removed.

public extension MarkdownThemeElement {
    @available(*, deprecated, renamed: "multilineTextAlignment(_:)")
    func textAlignment(_ alignment: TextAlignment) -> Self {
        multilineTextAlignment(alignment)
    }
}

public extension BlockImage {
    @available(*, deprecated, renamed: "cornerRadius(_:)")
    func borderRadius(_ value: CGFloat) -> Self {
        cornerRadius(value)
    }

    @available(*, deprecated, renamed: "cornerRadius")
    var borderRadius: CGFloat? {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
}

public extension CodeBlock {
    @available(*, deprecated, renamed: "cornerRadius(_:)")
    func borderRadius(_ value: CGFloat) -> Self {
        cornerRadius(value)
    }

    @available(*, deprecated, renamed: "cornerRadius")
    var borderRadius: CGFloat? {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
}

public extension Table {
    @available(*, deprecated, renamed: "cornerRadius(_:)")
    func borderRadius(_ value: CGFloat) -> Self {
        cornerRadius(value)
    }

    @available(*, deprecated, renamed: "cornerRadius")
    var borderRadius: CGFloat? {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    @available(*, deprecated, message: "Use alignment(_:) with .leading, .center, or .trailing.")
    func align(_ value: TableAlignment) -> Self {
        var copy = self
        copy.alignment = value
        return copy
    }

    @available(*, deprecated, renamed: "alignment")
    var align: TableAlignment? {
        get { alignment }
        set { alignment = newValue }
    }
}

public extension TaskList {
    @available(*, deprecated, renamed: "checkboxCornerRadius(_:)")
    func checkboxBorderRadius(_ value: CGFloat) -> Self {
        checkboxCornerRadius(value)
    }

    @available(*, deprecated, renamed: "checkboxCornerRadius")
    var checkboxBorderRadius: CGFloat? {
        get { checkboxCornerRadius }
        set { checkboxCornerRadius = newValue }
    }
}

public extension List {
    @available(*, deprecated, renamed: "marginLeading(_:)")
    func marginLeft(_ value: CGFloat) -> Self {
        marginLeading(value)
    }

    @available(*, deprecated, renamed: "marginLeading")
    var marginLeft: CGFloat? {
        get { marginLeading }
        set { marginLeading = newValue }
    }
}

public extension ThematicBreak {

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    @_disfavoredOverload
    func color(_ color: Color) -> Self {
        foregroundStyle(color)
    }

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        foregroundStyle(semantic)
    }
}

public extension Spoiler {

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    @_disfavoredOverload
    func color(_ color: Color) -> Self {
        foregroundStyle(color)
    }

    @available(*, deprecated, renamed: "foregroundStyle(_:)")
    func color(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        foregroundStyle(semantic)
    }
}

public extension BorderThemeElement {

    @available(*, deprecated, message: "Use border(_:width:), which sets the color and width together.")
    @_disfavoredOverload
    func borderColor(_ color: Color) -> Self {
        border(color)
    }

    @available(*, deprecated, message: "Use border(_:width:), which sets the color and width together.")
    func borderColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        border(semantic)
    }

    @available(*, deprecated, renamed: "border(width:)")
    func borderWidth(_ value: CGFloat) -> Self {
        border(width: value)
    }
}

public extension Table {

    @available(*, deprecated, renamed: "cellPadding(horizontal:vertical:)")
    func cellPaddingHorizontal(_ value: CGFloat) -> Self {
        cellPadding(horizontal: value)
    }

    @available(*, deprecated, renamed: "cellPadding(horizontal:vertical:)")
    func cellPaddingVertical(_ value: CGFloat) -> Self {
        cellPadding(vertical: value)
    }
}

public extension Spoiler {

    @available(*, deprecated, message: "Tune the overlay itself: .markdownSpoilerOverlay(.particles(density:speed:)).")
    func particleDensity(_ value: CGFloat) -> Self {
        var copy = self
        copy.particleDensity = value
        return copy
    }

    @available(*, deprecated, message: "Tune the overlay itself: .markdownSpoilerOverlay(.particles(density:speed:)).")
    func particleSpeed(_ value: CGFloat) -> Self {
        var copy = self
        copy.particleSpeed = value
        return copy
    }

    @available(*, deprecated, message: "Tune the overlay itself: .markdownSpoilerOverlay(.solid(cornerRadius:)).")
    func solidBorderRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.solidCornerRadius = value
        return copy
    }

    @available(*, deprecated, renamed: "solidCornerRadius")
    var solidBorderRadius: CGFloat? {
        get { solidCornerRadius }
        set { solidCornerRadius = newValue }
    }
}

public extension MarkdownThemeElement {
    @available(*, deprecated, renamed: "font(size:weight:design:)")
    func fontSize(_ size: CGFloat, weight: Font.Weight = .regular) -> Self {
        font(size: size, weight: weight)
    }

    @available(*, deprecated, renamed: "font(custom:size:)")
    func fontFamily(_ name: String, size: CGFloat) -> Self {
        font(custom: name, size: size)
    }
}

public extension Table {
    @available(*, deprecated, renamed: "headerFont(custom:size:)")
    func headerFontFamily(_ name: String, size: CGFloat) -> Self {
        headerFont(custom: name, size: size)
    }

    @available(*, deprecated, renamed: "headerForegroundStyle(_:)")
    @_disfavoredOverload
    func headerTextColor(_ color: Color) -> Self {
        headerForegroundStyle(color)
    }

    @available(*, deprecated, renamed: "headerForegroundStyle(_:)")
    func headerTextColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        headerForegroundStyle(semantic)
    }

    @available(*, deprecated, renamed: "headerForegroundColorSpec")
    var headerTextColorSpec: ThemeColorSpec? {
        get { headerForegroundColorSpec }
        set { headerForegroundColorSpec = newValue }
    }
}
