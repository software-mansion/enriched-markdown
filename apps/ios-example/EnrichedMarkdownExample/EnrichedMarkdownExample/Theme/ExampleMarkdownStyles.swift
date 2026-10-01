import EnrichedMarkdown
import SwiftUI

private enum ExampleFonts {
    static let montserratRegular = "Montserrat-Regular"
    static let montserratBold = "Montserrat-Bold"
    static let montserratSemiBold = "Montserrat-SemiBold"
    static let montserratMedium = "Montserrat-Medium"
    static let montserratItalic = "Montserrat-Italic"
    static let courierPrimeRegular = "CourierPrime-Regular"
}

/// Optional layered override with explicit hex colors matching Android `ExampleMarkdownStyles.kt`.
/// The library's `.default` theme uses semantic SwiftUI colors instead; apply this theme to
/// demonstrate cross-platform hex parity or custom branding.
let CustomMarkdownTheme = MarkdownTheme {
    Paragraph()
        .font(custom: ExampleFonts.montserratRegular, size: 16)
        .foregroundStyle(Color.gray800)
        .lineHeight(26)
        .marginBottom(16)

    Heading(1)
        .font(custom: ExampleFonts.montserratBold, size: 30)
        .foregroundStyle(Color.gray900)
        .lineHeight(38)
        .marginBottom(8)

    Heading(2)
        .font(custom: ExampleFonts.montserratBold, size: 24)
        .foregroundStyle(Color.gray900)
        .lineHeight(32)
        .marginBottom(8)

    Heading(3)
        .font(custom: ExampleFonts.montserratSemiBold, size: 20)
        .foregroundStyle(Color.gray800)
        .lineHeight(28)
        .marginBottom(8)

    Heading(4)
        .font(custom: ExampleFonts.montserratSemiBold, size: 18)
        .foregroundStyle(Color.gray800)
        .lineHeight(26)
        .marginBottom(8)

    Heading(5)
        .font(custom: ExampleFonts.montserratMedium, size: 16)
        .foregroundStyle(Color.gray700)
        .lineHeight(24)
        .marginBottom(8)

    Heading(6)
        .font(custom: ExampleFonts.montserratMedium, size: 14)
        .foregroundStyle(Color.gray600)
        .lineHeight(22)
        .marginBottom(8)

    Blockquote()
        .font(custom: ExampleFonts.montserratItalic, size: 16)
        .foregroundStyle(Color.gray600)
        .lineHeight(26)
        .border(Color.gray300, width: 3)
        .backgroundStyle(Color.gray50)
        .gapWidth(16)
        .marginBottom(16)

    List()
        .font(custom: ExampleFonts.montserratRegular, size: 16)
        .foregroundStyle(Color.gray800)
        .lineHeight(26)
        .bulletColor(Color.gray500)
        .bulletSize(6)
        .markerMinWidth(20)
        .markerColor(Color.gray500)
        .gapWidth(8)
        .marginLeading(24)
        .marginBottom(16)

    CodeBlock()
        .font(custom: ExampleFonts.courierPrimeRegular, size: 14)
        .foregroundStyle(Color.gray100)
        .backgroundStyle(Color.gray800)
        .border(Color.gray700, width: 1)
        .cornerRadius(8)
        .padding(16)
        .lineHeight(22)
        .marginBottom(16)

    Code()
        .foregroundStyle(Color.codeViolet)
        .backgroundStyle(Color.codeVioletBackground)

    // The Text screen forces a white page in both color schemes.
    Spoiler()
        .foregroundStyle(Color.gray700)
        .background(Color.white)

    Link()
        .font(custom: ExampleFonts.montserratBold, size: 16)
        .foregroundStyle(Color.linkBlue)
        .underline(true)

    Strong()
        .foregroundStyle(Color.gray900)

    Emphasis()
        .foregroundStyle(Color.gray600)

    BlockImage()
        .height(200)
        .cornerRadius(8)
        .marginBottom(16)

    InlineImage()
        .size(20)

    ThematicBreak()
        .foregroundStyle(Color.gray200)
        .height(1)
        .marginTop(24)
        .marginBottom(24)

    TaskList()
        .checkedColor(Color.linkBlue)
        .borderColor(Color.gray400)
        .checkboxSize(18)
        .checkboxCornerRadius(4)
        .checkmarkColor(Color.white)
        .checkedTextColor(Color.gray400)
        .checkedStrikethrough(true)
}

/// Mirrors Android PlaygroundMarkdownStyle.
let PlaygroundMarkdownTheme = MarkdownTheme {
    Link()
        .foregroundStyle(Color.linkBlue)
        .underline(true)

    Code()
        .foregroundStyle(Color.codeViolet)
        .backgroundStyle(Color.codeVioletBackground)

    CodeBlock()
        .foregroundStyle(Color.gray100)
        .backgroundStyle(Color.gray800)
        .cornerRadius(8)

    Blockquote()
        .foregroundStyle(Color.gray600)
        .border(Color.gray300, width: 3)
        .gapWidth(12)
}
