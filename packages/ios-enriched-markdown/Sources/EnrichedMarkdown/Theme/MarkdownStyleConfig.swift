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
    public var strong: ElementStyle
    public var emphasis: ElementStyle

    public init(
        paragraph: ElementStyle = ElementStyle(),
        strong: ElementStyle = ElementStyle(),
        emphasis: ElementStyle = ElementStyle()
    ) {
        self.paragraph = paragraph
        self.strong = strong
        self.emphasis = emphasis
    }

    public mutating func merge(_ other: MarkdownStyleConfig) {
        paragraph.merge(other.paragraph)
        strong.merge(other.strong)
        emphasis.merge(other.emphasis)
    }

}
