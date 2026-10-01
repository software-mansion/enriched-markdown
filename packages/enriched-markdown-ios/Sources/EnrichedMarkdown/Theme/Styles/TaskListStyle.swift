import UIKit

public struct TaskListStyle: Equatable, Sendable {
    public var checkedColor: UIColor?
    public var borderColor: UIColor?
    public var checkboxSize: CGFloat?
    public var checkboxCornerRadius: CGFloat?
    public var checkmarkColor: UIColor?
    public var checkedTextColor: UIColor?
    public var checkedStrikethrough: Bool?

    public init(
        checkedColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        checkboxSize: CGFloat? = nil,
        checkboxCornerRadius: CGFloat? = nil,
        checkmarkColor: UIColor? = nil,
        checkedTextColor: UIColor? = nil,
        checkedStrikethrough: Bool? = nil
    ) {
        self.checkedColor = checkedColor
        self.borderColor = borderColor
        self.checkboxSize = checkboxSize
        self.checkboxCornerRadius = checkboxCornerRadius
        self.checkmarkColor = checkmarkColor
        self.checkedTextColor = checkedTextColor
        self.checkedStrikethrough = checkedStrikethrough
    }

    public mutating func merge(_ other: TaskListStyle) {
        checkedColor = other.checkedColor ?? checkedColor
        borderColor = other.borderColor ?? borderColor
        checkboxSize = other.checkboxSize ?? checkboxSize
        checkboxCornerRadius = other.checkboxCornerRadius ?? checkboxCornerRadius
        checkmarkColor = other.checkmarkColor ?? checkmarkColor
        checkedTextColor = other.checkedTextColor ?? checkedTextColor
        checkedStrikethrough = other.checkedStrikethrough ?? checkedStrikethrough
    }
}
