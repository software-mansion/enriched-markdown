import UIKit
import XCTest
@testable import EnrichedMarkdown
@testable import EnrichedMarkdownSyntaxHighlighting

extension XCTestCase {
    func highlightingConfig(
        style: UIUserInterfaceStyle = .light,
        @MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup = { MarkdownThemeGroup(contents: []) }
    ) -> MarkdownStyleConfiguration {
        MarkdownStyleConfiguration.resolve(
            layers: [.default, .syntaxHighlightingDefault, MarkdownTheme(content)],
            traitCollection: UITraitCollection(userInterfaceStyle: style)
        )
    }

    func hex(_ color: UIColor?) -> UInt32? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        guard let color, color.getRed(&red, green: &green, blue: &blue, alpha: nil) else { return nil }
        return UInt32((red * 255).rounded()) << 16 | UInt32((green * 255).rounded()) << 8 | UInt32((blue * 255).rounded())
    }
}

extension NSAttributedString {
    func foregroundColor(of substring: String) -> UIColor? {
        let range = (string as NSString).range(of: substring)
        guard range.location != NSNotFound else { return nil }
        return attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? UIColor
    }
}

extension UIView {
    func firstSubview<T: UIView>(of type: T.Type) -> T? {
        for subview in subviews {
            if let match = subview as? T ?? subview.firstSubview(of: type) {
                return match
            }
        }
        return nil
    }
}

extension SyntaxHighlighter {
    static func tokens(in code: String, language: String) -> [Token] {
        tokens(in: Array(code.utf8), language: language)
    }
}
