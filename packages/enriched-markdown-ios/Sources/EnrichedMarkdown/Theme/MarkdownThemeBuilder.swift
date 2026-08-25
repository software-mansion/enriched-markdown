@resultBuilder
public enum MarkdownThemeBuilder {
    public static func buildBlock(_ components: any MarkdownThemeContent...) -> MarkdownThemeGroup {
        MarkdownThemeGroup(contents: components)
    }

    public static func buildOptional(_ component: (any MarkdownThemeContent)?) -> MarkdownThemeGroup {
        if let component {
            return MarkdownThemeGroup(contents: [component])
        }
        return MarkdownThemeGroup(contents: [])
    }

    public static func buildEither(first component: any MarkdownThemeContent) -> MarkdownThemeGroup {
        MarkdownThemeGroup(contents: [component])
    }

    public static func buildEither(second component: any MarkdownThemeContent) -> MarkdownThemeGroup {
        MarkdownThemeGroup(contents: [component])
    }

    public static func buildArray(_ components: [any MarkdownThemeContent]) -> MarkdownThemeGroup {
        MarkdownThemeGroup(contents: components)
    }
}
