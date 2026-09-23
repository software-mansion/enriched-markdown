import UIKit

public struct TaskListStyle: Equatable, Sendable {
    public var checkedColor: UIColor?
    public var borderColor: UIColor?
    public var checkboxSize: CGFloat?
    public var checkboxBorderRadius: CGFloat?
    public var checkmarkColor: UIColor?
    public var checkedTextColor: UIColor?
    public var checkedStrikethrough: Bool?

    public init(
        checkedColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        checkboxSize: CGFloat? = nil,
        checkboxBorderRadius: CGFloat? = nil,
        checkmarkColor: UIColor? = nil,
        checkedTextColor: UIColor? = nil,
        checkedStrikethrough: Bool? = nil
    ) {
        self.checkedColor = checkedColor
        self.borderColor = borderColor
        self.checkboxSize = checkboxSize
        self.checkboxBorderRadius = checkboxBorderRadius
        self.checkmarkColor = checkmarkColor
        self.checkedTextColor = checkedTextColor
        self.checkedStrikethrough = checkedStrikethrough
    }

    public mutating func merge(_ other: TaskListStyle) {
        checkedColor = other.checkedColor ?? checkedColor
        borderColor = other.borderColor ?? borderColor
        checkboxSize = other.checkboxSize ?? checkboxSize
        checkboxBorderRadius = other.checkboxBorderRadius ?? checkboxBorderRadius
        checkmarkColor = other.checkmarkColor ?? checkmarkColor
        checkedTextColor = other.checkedTextColor ?? checkedTextColor
        checkedStrikethrough = other.checkedStrikethrough ?? checkedStrikethrough
    }
}
