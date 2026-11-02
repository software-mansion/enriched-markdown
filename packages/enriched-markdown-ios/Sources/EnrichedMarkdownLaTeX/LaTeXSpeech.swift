import EnrichedMarkdownCppShim
import Foundation

/// Spoken English for a LaTeX formula ("x squared over 2" rather than
/// "x caret 2 slash 2"), produced by the shared C++ core.
public enum LaTeXSpeech {
    public static func spokenForm(of latex: String) -> String {
        guard let spoken = em_latex_spoken_form(latex) else { return latex }
        defer { em_string_release(spoken) }
        return String(cString: spoken)
    }
}
