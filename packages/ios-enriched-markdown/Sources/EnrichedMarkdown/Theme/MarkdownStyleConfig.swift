import UIKit

public struct ElementStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var backgroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var textAlignment: NSTextAlignment?
    public var underline: Bool?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        textAlignment: NSTextAlignment? = nil,
        underline: Bool? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.textAlignment = textAlignment
        self.underline = underline
    }

    public mutating func merge(_ other: ElementStyle) {
        if let font = other.font { self.font = font }
        if let foregroundColor = other.foregroundColor { self.foregroundColor = foregroundColor }
        if let backgroundColor = other.backgroundColor { self.backgroundColor = backgroundColor }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
        if let lineHeight = other.lineHeight { self.lineHeight = lineHeight }
        if let textAlignment = other.textAlignment { self.textAlignment = textAlignment }
        if let underline = other.underline { self.underline = underline }
    }
}

public struct ImageStyle: Equatable, Sendable {
    public var height: CGFloat?
    public var borderRadius: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init(
        height: CGFloat? = nil,
        borderRadius: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.height = height
        self.borderRadius = borderRadius
        self.marginTop = marginTop
        self.marginBottom = marginBottom
    }

    public mutating func merge(_ other: ImageStyle) {
        if let height = other.height { self.height = height }
        if let borderRadius = other.borderRadius { self.borderRadius = borderRadius }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
    }
}

public struct InlineImageStyle: Equatable, Sendable {
    public var size: CGFloat?

    public init(size: CGFloat? = nil) {
        self.size = size
    }

    public mutating func merge(_ other: InlineImageStyle) {
        if let size = other.size { self.size = size }
    }
}

public struct ThematicBreakStyle: Equatable, Sendable {
    public var color: UIColor?
    public var height: CGFloat?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?

    public init(
        color: UIColor? = nil,
        height: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.color = color
        self.height = height
        self.marginTop = marginTop
        self.marginBottom = marginBottom
    }

    public mutating func merge(_ other: ThematicBreakStyle) {
        if let color = other.color { self.color = color }
        if let height = other.height { self.height = height }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
    }
}

public struct CodeBlockStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var backgroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var padding: CGFloat?
    public var borderColor: UIColor?
    public var borderRadius: CGFloat?
    public var borderWidth: CGFloat?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        padding: CGFloat? = nil,
        borderColor: UIColor? = nil,
        borderRadius: CGFloat? = nil,
        borderWidth: CGFloat? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.padding = padding
        self.borderColor = borderColor
        self.borderRadius = borderRadius
        self.borderWidth = borderWidth
    }

    public mutating func merge(_ other: CodeBlockStyle) {
        if let font = other.font { self.font = font }
        if let foregroundColor = other.foregroundColor { self.foregroundColor = foregroundColor }
        if let backgroundColor = other.backgroundColor { self.backgroundColor = backgroundColor }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
        if let lineHeight = other.lineHeight { self.lineHeight = lineHeight }
        if let padding = other.padding { self.padding = padding }
        if let borderColor = other.borderColor { self.borderColor = borderColor }
        if let borderRadius = other.borderRadius { self.borderRadius = borderRadius }
        if let borderWidth = other.borderWidth { self.borderWidth = borderWidth }
    }
}

public struct BlockquoteStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var backgroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var borderColor: UIColor?
    public var borderWidth: CGFloat?
    public var gapWidth: CGFloat?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        gapWidth: CGFloat? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.borderColor = borderColor
        self.borderWidth = borderWidth
        self.gapWidth = gapWidth
    }

    public mutating func merge(_ other: BlockquoteStyle) {
        if let font = other.font { self.font = font }
        if let foregroundColor = other.foregroundColor { self.foregroundColor = foregroundColor }
        if let backgroundColor = other.backgroundColor { self.backgroundColor = backgroundColor }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
        if let lineHeight = other.lineHeight { self.lineHeight = lineHeight }
        if let borderColor = other.borderColor { self.borderColor = borderColor }
        if let borderWidth = other.borderWidth { self.borderWidth = borderWidth }
        if let gapWidth = other.gapWidth { self.gapWidth = gapWidth }
    }
}

public struct ListStyle: Equatable, Sendable {
    public var font: UIFont?
    public var foregroundColor: UIColor?
    public var marginTop: CGFloat?
    public var marginBottom: CGFloat?
    public var lineHeight: CGFloat?
    public var marginLeft: CGFloat?
    public var gapWidth: CGFloat?
    public var bulletColor: UIColor?
    public var bulletSize: CGFloat?
    public var markerMinWidth: CGFloat?
    public var markerColor: UIColor?

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        marginLeft: CGFloat? = nil,
        gapWidth: CGFloat? = nil,
        bulletColor: UIColor? = nil,
        bulletSize: CGFloat? = nil,
        markerMinWidth: CGFloat? = nil,
        markerColor: UIColor? = nil
    ) {
        self.font = font
        self.foregroundColor = foregroundColor
        self.marginTop = marginTop
        self.marginBottom = marginBottom
        self.lineHeight = lineHeight
        self.marginLeft = marginLeft
        self.gapWidth = gapWidth
        self.bulletColor = bulletColor
        self.bulletSize = bulletSize
        self.markerMinWidth = markerMinWidth
        self.markerColor = markerColor
    }

    public mutating func merge(_ other: ListStyle) {
        if let font = other.font { self.font = font }
        if let foregroundColor = other.foregroundColor { self.foregroundColor = foregroundColor }
        if let marginTop = other.marginTop { self.marginTop = marginTop }
        if let marginBottom = other.marginBottom { self.marginBottom = marginBottom }
        if let lineHeight = other.lineHeight { self.lineHeight = lineHeight }
        if let marginLeft = other.marginLeft { self.marginLeft = marginLeft }
        if let gapWidth = other.gapWidth { self.gapWidth = gapWidth }
        if let bulletColor = other.bulletColor { self.bulletColor = bulletColor }
        if let bulletSize = other.bulletSize { self.bulletSize = bulletSize }
        if let markerMinWidth = other.markerMinWidth { self.markerMinWidth = markerMinWidth }
        if let markerColor = other.markerColor { self.markerColor = markerColor }
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
    public var link: ElementStyle
    public var strong: ElementStyle
    public var emphasis: ElementStyle
    public var code: ElementStyle
    public var image: ImageStyle
    public var inlineImage: InlineImageStyle
    public var thematicBreak: ThematicBreakStyle
    public var codeBlock: CodeBlockStyle
    public var blockquote: BlockquoteStyle
    public var list: ListStyle

    public init(
        paragraph: ElementStyle = ElementStyle(),
        heading1: ElementStyle = ElementStyle(),
        heading2: ElementStyle = ElementStyle(),
        heading3: ElementStyle = ElementStyle(),
        heading4: ElementStyle = ElementStyle(),
        heading5: ElementStyle = ElementStyle(),
        heading6: ElementStyle = ElementStyle(),
        link: ElementStyle = ElementStyle(),
        strong: ElementStyle = ElementStyle(),
        emphasis: ElementStyle = ElementStyle(),
        code: ElementStyle = ElementStyle(),
        image: ImageStyle = ImageStyle(),
        inlineImage: InlineImageStyle = InlineImageStyle(),
        thematicBreak: ThematicBreakStyle = ThematicBreakStyle(),
        codeBlock: CodeBlockStyle = CodeBlockStyle(),
        blockquote: BlockquoteStyle = BlockquoteStyle(),
        list: ListStyle = ListStyle()
    ) {
        self.paragraph = paragraph
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.link = link
        self.strong = strong
        self.emphasis = emphasis
        self.code = code
        self.image = image
        self.inlineImage = inlineImage
        self.thematicBreak = thematicBreak
        self.codeBlock = codeBlock
        self.blockquote = blockquote
        self.list = list
    }

    public mutating func merge(_ other: MarkdownStyleConfig) {
        paragraph.merge(other.paragraph)
        heading1.merge(other.heading1)
        heading2.merge(other.heading2)
        heading3.merge(other.heading3)
        heading4.merge(other.heading4)
        heading5.merge(other.heading5)
        heading6.merge(other.heading6)
        link.merge(other.link)
        strong.merge(other.strong)
        emphasis.merge(other.emphasis)
        code.merge(other.code)
        image.merge(other.image)
        inlineImage.merge(other.inlineImage)
        thematicBreak.merge(other.thematicBreak)
        codeBlock.merge(other.codeBlock)
        blockquote.merge(other.blockquote)
        list.merge(other.list)
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
