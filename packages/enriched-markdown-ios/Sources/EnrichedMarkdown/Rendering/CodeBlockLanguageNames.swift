import Foundation

/// The label a scrollable code block's header shows for a fence language.
/// Mirrors the table in packages/core/cpp/highlight/CodeBlockLanguages.cpp.
enum CodeBlockLanguageNames {
    private static let names: [String: String] = [
        "bash": "Bash",
        "c": "C",
        "cc": "C++",
        "cpp": "C++",
        "cs": "C#",
        "csharp": "C#",
        "css": "CSS",
        "cxx": "C++",
        "dockerfile": "Dockerfile",
        "go": "Go",
        "golang": "Go",
        "graphql": "GraphQL",
        "html": "HTML",
        "java": "Java",
        "javascript": "JavaScript",
        "js": "JavaScript",
        "json": "JSON",
        "jsx": "JSX",
        "markdown": "Markdown",
        "md": "Markdown",
        "objc": "Objective-C",
        "objectivec": "Objective-C",
        "php": "PHP",
        "py": "Python",
        "python": "Python",
        "rb": "Ruby",
        "rs": "Rust",
        "ruby": "Ruby",
        "rust": "Rust",
        "scss": "SCSS",
        "sh": "Shell",
        "shell": "Shell",
        "sql": "SQL",
        "swift": "Swift",
        "toml": "TOML",
        "ts": "TypeScript",
        "tsx": "TSX",
        "typescript": "TypeScript",
        "xml": "XML",
        "yaml": "YAML",
        "yml": "YAML",
        "zsh": "Zsh"
    ]

    /// An unknown language is shown as written, with its first letter capitalized.
    static func displayName(for language: String) -> String {
        let lowered = language.lowercased()
        if let name = names[lowered] { return name }
        return lowered.prefix(1).uppercased() + lowered.dropFirst()
    }
}
