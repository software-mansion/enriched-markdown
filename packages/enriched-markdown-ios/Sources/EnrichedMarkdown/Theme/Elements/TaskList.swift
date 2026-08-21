import SwiftUI

public struct TaskList: MarkdownThemeContent {
    public var checkedColorSpec: ThemeColorSpec?
    public var borderColorSpec: ThemeColorSpec?
    public var checkmarkColorSpec: ThemeColorSpec?
    public var checkedTextColorSpec: ThemeColorSpec?
    public var checkboxSize: CGFloat?
    public var checkboxBorderRadius: CGFloat?
    public var checkedStrikethrough: Bool?

    public init() {}

    public func checkedColor(_ color: Color) -> Self {
        var copy = self
        copy.checkedColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func checkedColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.checkedColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func borderColor(_ color: Color) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func borderColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.borderColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func checkmarkColor(_ color: Color) -> Self {
        var copy = self
        copy.checkmarkColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func checkmarkColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.checkmarkColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func checkedTextColor(_ color: Color) -> Self {
        var copy = self
        copy.checkedTextColorSpec = ThemeColorModifiers.spec(from: color)
        return copy
    }

    public func checkedTextColor(_ semantic: ThemeColorSpec.SemanticColor) -> Self {
        var copy = self
        copy.checkedTextColorSpec = ThemeColorModifiers.spec(from: semantic)
        return copy
    }

    public func checkboxSize(_ value: CGFloat) -> Self {
        var copy = self
        copy.checkboxSize = value
        return copy
    }

    public func checkboxBorderRadius(_ value: CGFloat) -> Self {
        var copy = self
        copy.checkboxBorderRadius = value
        return copy
    }

    public func checkedStrikethrough(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.checkedStrikethrough = enabled
        return copy
    }

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        if let checkedColorSpec {
            config.taskList.checkedColor = checkedColorSpec.resolve(traitCollection: traitCollection)
        }
        if let borderColorSpec {
            config.taskList.borderColor = borderColorSpec.resolve(traitCollection: traitCollection)
        }
        if let checkmarkColorSpec {
            config.taskList.checkmarkColor = checkmarkColorSpec.resolve(traitCollection: traitCollection)
        }
        if let checkedTextColorSpec {
            config.taskList.checkedTextColor = checkedTextColorSpec.resolve(traitCollection: traitCollection)
        }
        if let checkboxSize { config.taskList.checkboxSize = checkboxSize }
        if let checkboxBorderRadius { config.taskList.checkboxBorderRadius = checkboxBorderRadius }
        if let checkedStrikethrough { config.taskList.checkedStrikethrough = checkedStrikethrough }
    }
}
