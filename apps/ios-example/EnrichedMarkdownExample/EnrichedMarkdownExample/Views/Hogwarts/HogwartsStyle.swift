import SwiftUI

enum HogwartsPalette {
    static let night = Color(red: 0.02, green: 0.03, blue: 0.08)
    static let parchment = Color(red: 0.93, green: 0.87, blue: 0.72)
    static let ink = Color(red: 0.22, green: 0.14, blue: 0.08)
    static let inkSoft = Color(red: 0.42, green: 0.3, blue: 0.18)
    static let gold = Color(red: 0.86, green: 0.7, blue: 0.32)
    static let goldDeep = Color(red: 0.6, green: 0.45, blue: 0.15)
    static let leather = Color(red: 0.24, green: 0.1, blue: 0.06)
    static let wax = Color(red: 0.55, green: 0.08, blue: 0.1)
}

/// Cinzel Decorative and IM Fell English, bundled under the Open Font
/// License: Roman capitals with flourishes for the spell names, and a
/// seventeenth-century book face for the page.
enum HogwartsFont {
    static let display = "CinzelDecorative-Bold"
    static let caps = "CinzelDecorative-Regular"
    static let body = "IM_FELL_English_Roman"
    static let bodyItalic = "IM_FELL_English_Italic"
    static let smallCaps = "IM_FELL_English_SC"
    static let hand = "SnellRoundhand-Bold"
}
