import UIKit

public struct ElementStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: NSTextAlignment?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        textAlignment: NSTextAlignment? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.textAlignment = textAlignment
    }

    public mutating func merge(_ other: ElementStyle) {
        if let font = other.font { self.font = font }
        if let foregroundColor = other.foregroundColor { self.foregroundColor = foregroundColor }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
        if let lineHeight = other.lineHeight { self.lineHeight = lineHeight }
        if let textAlignment = other.textAlignment { self.textAlignment = textAlignment }
    }
}

public struct MarkdownStyleConfig: Equatable, Sendable {
    public var paragraph: ElementStyle
    public var heading1: ElementStyle
    public var heading2: ElementStyle
    public var heading3: ElementStyle
    public var heading4: ElementStyle
    public var heading5: ElementStyle
    public var heading6: ElementStyle
    public var strong: ElementStyle
    public var emphasis: ElementStyle

    public init(
        paragraph: ElementStyle = ElementStyle(),
        heading1: ElementStyle = ElementStyle(),
        heading2: ElementStyle = ElementStyle(),
        heading3: ElementStyle = ElementStyle(),
        heading4: ElementStyle = ElementStyle(),
        heading5: ElementStyle = ElementStyle(),
        heading6: ElementStyle = ElementStyle(),
        strong: ElementStyle = ElementStyle(),
        emphasis: ElementStyle = ElementStyle()
    ) {
        self.paragraph = paragraph
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.strong = strong
        self.emphasis = emphasis
    }

    public mutating func merge(_ other: MarkdownStyleConfig) {
        paragraph.merge(other.paragraph)
        heading1.merge(other.heading1)
        heading2.merge(other.heading2)
        heading3.merge(other.heading3)
        heading4.merge(other.heading4)
        heading5.merge(other.heading5)
        heading6.merge(other.heading6)
        strong.merge(other.strong)
        emphasis.merge(other.emphasis)
    }

    public func headingStyle(for level: Int) -> ElementStyle {
        switch level {
        case 1: return heading1
        case 2: return heading2
        case 3: return heading3
        case 4: return heading4
        case 5: return heading5
        case 6: return heading6
        default: return heading1
        }
    }

    public mutating func setHeadingStyle(_ style: ElementStyle, for level: Int) {
        switch level {
        case 1: heading1 = style
        case 2: heading2 = style
        case 3: heading3 = style
        case 4: heading4 = style
        case 5: heading5 = style
        case 6: heading6 = style
        default: heading1 = style
        }
    }
}
