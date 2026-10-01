import UIKit

// Shims for the 0.1 style-record field names and memberwise-init labels.
// Each deprecated init requires its old label, so a call without it always
// picks the live init. Delete this file when they are removed.

public extension CodeBlockStyle {
    @available(*, deprecated, renamed: "cornerRadius")
    var borderRadius: CGFloat? {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    @available(*, deprecated, message: "The borderRadius: label is now cornerRadius:.")
    init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        padding: CGFloat? = nil,
        borderColor: UIColor? = nil,
        borderRadius: CGFloat?,
        borderWidth: CGFloat? = nil
    ) {
        self.init(
            font: font,
            foregroundColor: foregroundColor,
            backgroundColor: backgroundColor,
            marginTop: marginTop,
            marginBottom: marginBottom,
            lineHeight: lineHeight,
            padding: padding,
            borderColor: borderColor,
            cornerRadius: borderRadius,
            borderWidth: borderWidth
        )
    }
}

public extension ImageStyle {
    @available(*, deprecated, renamed: "cornerRadius")
    var borderRadius: CGFloat? {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    @available(*, deprecated, message: "The borderRadius: label is now cornerRadius:.")
    init(
        sizing: ImageSizing? = nil,
        contentMode: ImageContentMode? = nil,
        borderRadius: CGFloat?,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.init(
            sizing: sizing,
            contentMode: contentMode,
            cornerRadius: borderRadius,
            marginTop: marginTop,
            marginBottom: marginBottom
        )
    }
}

public extension TaskListStyle {
    @available(*, deprecated, renamed: "checkboxCornerRadius")
    var checkboxBorderRadius: CGFloat? {
        get { checkboxCornerRadius }
        set { checkboxCornerRadius = newValue }
    }

    @available(*, deprecated, message: "The checkboxBorderRadius: label is now checkboxCornerRadius:.")
    init(
        checkedColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        checkboxSize: CGFloat? = nil,
        checkboxBorderRadius: CGFloat?,
        checkmarkColor: UIColor? = nil,
        checkedTextColor: UIColor? = nil,
        checkedStrikethrough: Bool? = nil
    ) {
        self.init(
            checkedColor: checkedColor,
            borderColor: borderColor,
            checkboxSize: checkboxSize,
            checkboxCornerRadius: checkboxBorderRadius,
            checkmarkColor: checkmarkColor,
            checkedTextColor: checkedTextColor,
            checkedStrikethrough: checkedStrikethrough
        )
    }
}

public extension ListStyle {
    @available(*, deprecated, renamed: "marginLeading")
    var marginLeft: CGFloat? {
        get { marginLeading }
        set { marginLeading = newValue }
    }

    @available(*, deprecated, message: "The marginLeft: label is now marginLeading:.")
    init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        lineHeight: CGFloat? = nil,
        marginLeft: CGFloat?,
        gapWidth: CGFloat? = nil,
        bulletColor: UIColor? = nil,
        bulletSize: CGFloat? = nil,
        markerMinWidth: CGFloat? = nil,
        markerColor: UIColor? = nil
    ) {
        self.init(
            font: font,
            foregroundColor: foregroundColor,
            marginTop: marginTop,
            marginBottom: marginBottom,
            lineHeight: lineHeight,
            marginLeading: marginLeft,
            gapWidth: gapWidth,
            bulletColor: bulletColor,
            bulletSize: bulletSize,
            markerMinWidth: markerMinWidth,
            markerColor: markerColor
        )
    }
}

public extension TableStyle {
    @available(*, deprecated, renamed: "cornerRadius")
    var borderRadius: CGFloat? {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    @available(*, deprecated, renamed: "alignment")
    var align: TableAlignment? {
        get { alignment }
        set { alignment = newValue }
    }

    // Three inits cover `borderRadius:` alone, `align:` alone, and both.

    @available(*, deprecated, message: "The borderRadius: and align: labels are now cornerRadius: and alignment:.")
    init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        lineHeight: CGFloat? = nil,
        headerFont: UIFont? = nil,
        headerTextColor: UIColor? = nil,
        headerBackgroundColor: UIColor? = nil,
        rowEvenBackgroundColor: UIColor? = nil,
        rowOddBackgroundColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        borderRadius: CGFloat?,
        cellPaddingHorizontal: CGFloat? = nil,
        cellPaddingVertical: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        align: TableAlignment?
    ) {
        self.init(
            font: font, foregroundColor: foregroundColor, lineHeight: lineHeight,
            headerFont: headerFont, headerTextColor: headerTextColor,
            headerBackgroundColor: headerBackgroundColor,
            rowEvenBackgroundColor: rowEvenBackgroundColor, rowOddBackgroundColor: rowOddBackgroundColor,
            borderColor: borderColor, borderWidth: borderWidth, cornerRadius: borderRadius,
            cellPaddingHorizontal: cellPaddingHorizontal, cellPaddingVertical: cellPaddingVertical,
            marginTop: marginTop, marginBottom: marginBottom, alignment: align
        )
    }

    @available(*, deprecated, message: "The borderRadius: and align: labels are now cornerRadius: and alignment:.")
    init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        lineHeight: CGFloat? = nil,
        headerFont: UIFont? = nil,
        headerTextColor: UIColor? = nil,
        headerBackgroundColor: UIColor? = nil,
        rowEvenBackgroundColor: UIColor? = nil,
        rowOddBackgroundColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        borderRadius: CGFloat?,
        cellPaddingHorizontal: CGFloat? = nil,
        cellPaddingVertical: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil
    ) {
        self.init(
            font: font, foregroundColor: foregroundColor, lineHeight: lineHeight,
            headerFont: headerFont, headerTextColor: headerTextColor,
            headerBackgroundColor: headerBackgroundColor,
            rowEvenBackgroundColor: rowEvenBackgroundColor, rowOddBackgroundColor: rowOddBackgroundColor,
            borderColor: borderColor, borderWidth: borderWidth, cornerRadius: borderRadius,
            cellPaddingHorizontal: cellPaddingHorizontal, cellPaddingVertical: cellPaddingVertical,
            marginTop: marginTop, marginBottom: marginBottom
        )
    }

    @available(*, deprecated, message: "The borderRadius: and align: labels are now cornerRadius: and alignment:.")
    init(
        font: UIFont? = nil,
        foregroundColor: UIColor? = nil,
        lineHeight: CGFloat? = nil,
        headerFont: UIFont? = nil,
        headerTextColor: UIColor? = nil,
        headerBackgroundColor: UIColor? = nil,
        rowEvenBackgroundColor: UIColor? = nil,
        rowOddBackgroundColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil,
        cellPaddingHorizontal: CGFloat? = nil,
        cellPaddingVertical: CGFloat? = nil,
        marginTop: CGFloat? = nil,
        marginBottom: CGFloat? = nil,
        align: TableAlignment?
    ) {
        self.init(
            font: font, foregroundColor: foregroundColor, lineHeight: lineHeight,
            headerFont: headerFont, headerTextColor: headerTextColor,
            headerBackgroundColor: headerBackgroundColor,
            rowEvenBackgroundColor: rowEvenBackgroundColor, rowOddBackgroundColor: rowOddBackgroundColor,
            borderColor: borderColor, borderWidth: borderWidth,
            cellPaddingHorizontal: cellPaddingHorizontal, cellPaddingVertical: cellPaddingVertical,
            marginTop: marginTop, marginBottom: marginBottom, alignment: align
        )
    }
}

public extension SpoilerStyle {
    @available(*, deprecated, renamed: "solidCornerRadius")
    var solidBorderRadius: CGFloat? {
        get { solidCornerRadius }
        set { solidCornerRadius = newValue }
    }

    @available(*, deprecated, message: "The solidBorderRadius: label is now solidCornerRadius:.")
    init(
        color: UIColor? = nil,
        backgroundColor: UIColor? = nil,
        particleDensity: CGFloat? = nil,
        particleSpeed: CGFloat? = nil,
        solidBorderRadius: CGFloat?
    ) {
        self.init(
            color: color,
            backgroundColor: backgroundColor,
            particleDensity: particleDensity,
            particleSpeed: particleSpeed,
            solidCornerRadius: solidBorderRadius
        )
    }
}

@available(*, deprecated, renamed: "MarkdownStyleConfiguration")
public typealias MarkdownStyleConfig = MarkdownStyleConfiguration
