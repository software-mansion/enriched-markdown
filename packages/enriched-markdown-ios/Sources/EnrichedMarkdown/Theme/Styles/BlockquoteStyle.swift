import UIKit

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
    /// Per-type colors for `> [!NOTE]`-style alerts (`MarkdownParsingOptions(admonitions: true)`).
    public var admonitions: [AdmonitionType: AdmonitionStyle]

    public init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        gapWidth: CGFloat? = nil,
        admonitions: [AdmonitionType: AdmonitionStyle] = [:]
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
        self.admonitions = admonitions
    }

    public mutating func merge(_ other: BlockquoteStyle) {
        font = other.font ?? font
        foregroundColor = other.foregroundColor ?? foregroundColor
        backgroundColor = other.backgroundColor ?? backgroundColor
        marginTop = other.marginTop ?? marginTop
        marginBottom = other.marginBottom ?? marginBottom
        lineHeight = other.lineHeight ?? lineHeight
        borderColor = other.borderColor ?? borderColor
        borderWidth = other.borderWidth ?? borderWidth
        gapWidth = other.gapWidth ?? gapWidth
        for (type, style) in other.admonitions {
            admonitions[type, default: AdmonitionStyle()].merge(style)
        }
    }

    var resolvedBorderColor: UIColor {
        borderColor ?? BlockDecorationConfig.defaultBlockquoteBorderColor
    }

    func admonitionTint(for type: AdmonitionType) -> UIColor {
        admonitions[type]?.color ?? resolvedBorderColor
    }
}
