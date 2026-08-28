import UIKit

public struct Superscript: BaselineShiftThemeElement {
    public var fontScale: CGFloat?
    public var baselineOffsetScale: CGFloat?

    public init() {}

    public func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        applyBaselineShiftStyle(to: &config.superscript)
    }
}
