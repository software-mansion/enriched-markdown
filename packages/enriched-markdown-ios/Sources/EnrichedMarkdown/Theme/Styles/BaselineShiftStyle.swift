import UIKit

public struct BaselineShiftStyle: Equatable, Sendable {
    public var fontScale: CGFloat?
    public var baselineOffsetScale: CGFloat?

    public init(
        fontScale: CGFloat? = nil,
        baselineOffsetScale: CGFloat? = nil
    ) {
        self.fontScale = fontScale
        self.baselineOffsetScale = baselineOffsetScale
    }

    public mutating func merge(_ other: BaselineShiftStyle) {
        fontScale = other.fontScale ?? fontScale
        baselineOffsetScale = other.baselineOffsetScale ?? baselineOffsetScale
    }
}
