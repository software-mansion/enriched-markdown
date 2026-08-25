import SwiftUI

/// Centralized example-app palette so views never hard-code color components.
/// The grayscale/accent palette values match the Android example app
/// (`ExampleMarkdownStyles.kt`) for cross-platform parity — keep them in sync.
extension Color {
    // MARK: - Brand

    static var brandMint: Color { Color(red: 190 / 255, green: 235 / 255, blue: 208 / 255) }
    static var brandNavy: Color { Color(red: 0 / 255, green: 26 / 255, blue: 114 / 255) }

    // MARK: - Home screen

    static var homeBackground: Color { Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255) }
    static var secondaryText: Color { Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255) }

    static var tileBlue: Color { Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255) }
    static var tileGreen: Color { Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255) }
    static var tileOrange: Color { Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255) }
    static var tilePurple: Color { Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255) }
    static var tilePink: Color { Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255) }

    // MARK: - Grayscale palette (Tailwind gray)

    static var gray50: Color { Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255) }
    static var gray100: Color { Color(red: 243 / 255, green: 244 / 255, blue: 246 / 255) }
    static var gray200: Color { Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255) }
    static var gray300: Color { Color(red: 209 / 255, green: 213 / 255, blue: 219 / 255) }
    static var gray400: Color { Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255) }
    static var gray500: Color { Color(red: 107 / 255, green: 114 / 255, blue: 128 / 255) }
    static var gray600: Color { Color(red: 75 / 255, green: 85 / 255, blue: 99 / 255) }
    static var gray700: Color { Color(red: 55 / 255, green: 65 / 255, blue: 81 / 255) }
    static var gray800: Color { Color(red: 31 / 255, green: 41 / 255, blue: 55 / 255) }
    static var gray900: Color { Color(red: 17 / 255, green: 24 / 255, blue: 39 / 255) }

    // MARK: - Markdown accents (Tailwind blue/violet)

    static var linkBlue: Color { Color(red: 37 / 255, green: 99 / 255, blue: 235 / 255) }
    static var codeViolet: Color { Color(red: 124 / 255, green: 58 / 255, blue: 237 / 255) }
    static var codeVioletBackground: Color { Color(red: 245 / 255, green: 243 / 255, blue: 255 / 255) }
}
