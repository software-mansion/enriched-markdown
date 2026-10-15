import EnrichedMarkdownCppShim
import Foundation

enum CodeBlockLanguageNames {
    static func displayName(for language: String) -> String {
        guard let name = em_code_block_language_display_name(language) else { return language }
        defer { em_string_release(name) }
        return String(cString: name)
    }
}
