import UIKit

public struct LinkVariantStyle: Equatable, Sendable {
    public var pattern: String
    public var style: ElementStyle

    public init(pattern: String, style: ElementStyle = ElementStyle()) {
        self.pattern = pattern
        self.style = style
    }
}
