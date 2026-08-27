import UIKit

/// Verifies a candidate source slice against the selection it should
/// represent: re-parsed with the render flags, the slice must carry exactly
/// the selection's visible text (whitespace-insensitive) and the same
/// table/image/thematic-break structure. This is what turns every mapping
/// or expansion defect in the slicer into a fallback instead of wrong
/// clipboard content. The structural counts matter because textless
/// elements (a duplicated `---` from a mis-anchor) would otherwise pass.
enum MarkdownSliceValidator {
    static func isFaithful(
        _ slice: String,
        toSelection selection: NSRange,
        in attributedText: NSAttributedString,
        flags: Md4cFlags
    ) -> Bool {
        var parsed = ContentSummary()
        summarize(Parser.shared.parseMarkdown(slice, flags: flags), into: &parsed)
        var selected = ContentSummary()
        summarizeSelection(selection, in: attributedText, into: &selected)
        return canonical(parsed.text) == canonical(selected.text)
            && parsed.tables == selected.tables
            && parsed.images == selected.images
            && parsed.breaks == selected.breaks
    }
}

private extension MarkdownSliceValidator {
    struct ContentSummary {
        var text = ""
        var tables = 0
        var images = 0
        var breaks = 0
    }

    static func summarize(_ node: MarkdownASTNode, into summary: inout ContentSummary) {
        switch node.type {
        case .image:
            // Alt text is invisible in rendered output.
            summary.images += 1
            return
        case .table:
            summary.tables += 1
        case .thematicBreak:
            summary.breaks += 1
        case .text:
            summary.text += node.content
        default:
            break
        }
        for child in node.children {
            summarize(child, into: &summary)
        }
    }

    static func summarizeSelection(
        _ selection: NSRange,
        in attributedText: NSAttributedString,
        into summary: inout ContentSummary
    ) {
        let string = attributedText.string as NSString
        attributedText.enumerateAttribute(.attachment, in: selection, options: []) { value, runRange, _ in
            switch value {
            case let table as TableAttachment:
                summary.tables += 1
                summary.text += table.plainText()
            case is MarkdownImageAttachment:
                summary.images += 1
            case is ThematicBreakAttachment:
                summary.breaks += 1
            default:
                summary.text += string.substring(with: runRange)
            }
        }
    }

    static let strippable = MarkdownExtractor.invisibleCharacters
        .union(CharacterSet(charactersIn: "\u{FFFC}"))

    static func canonical(_ text: String) -> String {
        String(String.UnicodeScalarView(text.unicodeScalars.filter { !strippable.contains($0) }))
    }
}
