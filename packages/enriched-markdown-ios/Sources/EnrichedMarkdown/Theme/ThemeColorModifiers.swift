import SwiftUI

package enum ThemeColorModifiers {
    package static func spec(from color: Color) -> ThemeColorSpec {
        ThemeResolver.color(from: color, traitCollection: .current)
    }

    package static func spec(from semantic: ThemeColorSpec.SemanticColor) -> ThemeColorSpec {
        .semantic(semantic)
    }
}
