import SwiftUI
import UIKit

public struct MarkdownTheme: Sendable {
    private let content: any MarkdownThemeContent

    public init(@MarkdownThemeBuilder _ content: () -> MarkdownThemeGroup) {
        self.content = content()
    }

    init(content: any MarkdownThemeContent) {
        self.content = content
    }

    func apply(to config: inout MarkdownStyleConfig, traitCollection: UITraitCollection) {
        content.apply(to: &config, traitCollection: traitCollection)
    }

    public static let `default` = DefaultMarkdownTheme.make()
}
