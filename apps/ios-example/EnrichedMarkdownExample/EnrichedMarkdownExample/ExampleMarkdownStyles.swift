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
        .fontFamily(ExampleFonts.montserratRegular, size: 16)
        .foregroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
        .lineHeight(26)
        .marginBottom(16)

    Heading(1)
        .fontFamily(ExampleFonts.montserratBold, size: 30)
        .foregroundStyle(Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255))
        .lineHeight(38)
        .marginBottom(8)

    Heading(2)
        .fontFamily(ExampleFonts.montserratBold, size: 24)
        .foregroundStyle(Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255))
        .lineHeight(32)
        .marginBottom(8)

    Heading(3)
        .fontFamily(ExampleFonts.montserratSemiBold, size: 20)
        .foregroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
        .lineHeight(28)
        .marginBottom(8)

    Heading(4)
        .fontFamily(ExampleFonts.montserratSemiBold, size: 18)
        .foregroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
        .lineHeight(26)
        .marginBottom(8)

    Heading(5)
        .fontFamily(ExampleFonts.montserratMedium, size: 16)
        .foregroundStyle(Color(red: 55 / 255, green: 65 / 255, blue: 81 / 255))
        .lineHeight(24)
        .marginBottom(8)

    Heading(6)
        .fontFamily(ExampleFonts.montserratMedium, size: 14)
        .foregroundStyle(Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255))
        .lineHeight(22)
        .marginBottom(8)

    Blockquote()
        .fontFamily(ExampleFonts.montserratItalic, size: 16)
        .foregroundStyle(Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255))
        .lineHeight(26)
        .borderColor(Color(red: 209 / 255, green: 213 / 255, blue: 219 / 255))
        .borderWidth(3)
        .backgroundStyle(Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255))
        .gapWidth(16)
        .marginBottom(16)

    List()
        .fontFamily(ExampleFonts.montserratRegular, size: 16)
        .foregroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
        .lineHeight(26)
        .bulletColor(Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255))
        .bulletSize(6)
        .markerMinWidth(20)
        .markerColor(Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255))
        .gapWidth(8)
        .marginLeft(24)
        .marginBottom(16)

    CodeBlock()
        .fontFamily(ExampleFonts.courierPrimeRegular, size: 14)
        .foregroundStyle(Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255))
        .backgroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
        .borderColor(Color(red: 55 / 255, green: 65 / 255, blue: 81 / 255))
        .borderWidth(1)
        .borderRadius(8)
        .padding(16)
        .lineHeight(22)
        .marginBottom(16)

    Code()
        .foregroundStyle(Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255))
        .backgroundStyle(Color(red: 245 / 255, green: 243 / 255, blue: 255 / 255))

    Link()
        .fontFamily(ExampleFonts.montserratBold, size: 16)
        .foregroundStyle(Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255))
        .underline(true)

    Strong()
        .foregroundStyle(Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255))

    Emphasis()
        .foregroundStyle(Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255))

    BlockImage()
        .height(200)
        .borderRadius(8)
        .marginBottom(16)

    InlineImage()
        .size(20)

    ThematicBreak()
        .color(Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255))
        .height(1)
        .marginTop(24)
        .marginBottom(24)
}

/// Mirrors Android PlaygroundMarkdownStyle.
let PlaygroundMarkdownTheme = MarkdownTheme {
    Link()
        .foregroundStyle(Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255))
        .underline(true)

    Code()
        .foregroundStyle(Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255))
        .backgroundStyle(Color(red: 245 / 255, green: 243 / 255, blue: 255 / 255))

    CodeBlock()
        .foregroundStyle(Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255))
        .backgroundStyle(Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255))
        .borderRadius(8)

    Blockquote()
        .foregroundStyle(Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255))
        .borderColor(Color(red: 209 / 255, green: 213 / 255, blue: 219 / 255))
        .borderWidth(3)
        .gapWidth(12)
}
