import SwiftUI

enum ThemeColorModifiers {
    static func spec(from color: Color) -> ThemeColorSpec {
        ThemeResolver.color(from: color, traitCollection: .current)
    }

    static func spec(from semantic: ThemeColorSpec.SemanticColor) -> ThemeColorSpec {
        .semantic(semantic)
    }
}
