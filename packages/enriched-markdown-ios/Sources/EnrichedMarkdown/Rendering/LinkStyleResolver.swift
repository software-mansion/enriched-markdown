import UIKit

struct LinkStyleResolver<Style> {
    private let base: Style
    private let variants: [(regex: NSRegularExpression, style: Style)]

    init(config: MarkdownStyleConfiguration, transform: (ElementStyle) -> Style) {
        base = transform(config.link)
        variants = config.linkVariants
            .sorted { $0.pattern.count > $1.pattern.count }
            .compactMap { variant in
                guard let regex = try? NSRegularExpression(pattern: variant.pattern) else {
                    #if DEBUG
                    print("[EnrichedMarkdown] Ignoring the link variant '\(variant.pattern)': not a valid pattern.")
                    #endif
                    return nil
                }
                var style = config.link
                style.merge(variant.style)
                return (regex, transform(style))
            }
    }

    func resolve(_ url: String) -> Style {
        let range = NSRange(location: 0, length: url.utf16.count)
        return variants.first { $0.regex.firstMatch(in: url, range: range) != nil }?.style ?? base
    }
}

extension LinkStyleResolver where Style == ElementStyle {
    init(config: MarkdownStyleConfiguration) {
        self.init(config: config) { $0 }
    }
}
