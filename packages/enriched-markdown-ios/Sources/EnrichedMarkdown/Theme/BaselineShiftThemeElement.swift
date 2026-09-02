import UIKit

public protocol BaselineShiftThemeElement: MarkdownThemeContent {
    var fontScale: CGFloat? { get set }
    var baselineOffsetScale: CGFloat? { get set }
}

public extension BaselineShiftThemeElement {
    /// Font size as a fraction of the surrounding text size.
    func fontScale(_ value: CGFloat) -> Self {
        var copy = self
        copy.fontScale = value
        return copy
    }

    /// Baseline shift as a fraction of the surrounding text size — upward
    /// for `Superscript`, downward for `Subscript`.
    func baselineOffsetScale(_ value: CGFloat) -> Self {
        var copy = self
        copy.baselineOffsetScale = value
        return copy
    }

    func applyBaselineShiftStyle(to style: inout BaselineShiftStyle) {
        if let fontScale { style.fontScale = fontScale }
        if let baselineOffsetScale { style.baselineOffsetScale = baselineOffsetScale }
    }
}
