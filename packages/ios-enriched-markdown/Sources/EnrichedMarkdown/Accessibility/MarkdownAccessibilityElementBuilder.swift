import UIKit

/// A VoiceOver element description derived from the rendered attributed
/// string. Pure data so the segmentation logic is unit-testable; frames are
/// resolved lazily by `MarkdownAccessibilityElement` at query time.
struct MarkdownAccessibilityElementSpec: Equatable {
    enum Kind: Equatable {
        case text
        case heading(level: Int)
        case link(URL)
        case image
    }

    let kind: Kind
    let label: String
    /// Trimmed character range used for frame calculation.
    let range: NSRange
    /// Spoken list context ("bullet point", "list item 2", "nested …").
    let listAnnouncement: String?
}

/// Segments the rendered attributed string into VoiceOver elements: split
/// into paragraphs, drop spacer-only paragraphs, and carve heading/link/
/// image runs into their own elements with plain text between them.
enum MarkdownAccessibilityElementBuilder {
    /// Zero-width space (list marker anchors) and line separator join plain
    /// whitespace as "invisible" for trimming; U+FFFC attachment characters
    /// count as content.
    private static let skippable: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "\u{200B}\u{2028}")
        return set
    }()

    static func specs(for text: NSAttributedString) -> [MarkdownAccessibilityElementSpec] {
        let string = text.string as NSString
        guard string.length > 0 else { return [] }

        var specs: [MarkdownAccessibilityElementSpec] = []
        var paragraphStart = 0
        while paragraphStart < string.length {
            let searchRange = NSRange(location: paragraphStart, length: string.length - paragraphStart)
            let newline = string.range(of: "\n", options: [], range: searchRange)
            let paragraphEnd = newline.location == NSNotFound ? string.length : newline.location + 1
            appendSpecs(
                for: NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart),
                in: text,
                to: &specs
            )
            paragraphStart = paragraphEnd
        }
        return specs
    }

    // MARK: - Paragraph segmentation

    private struct SemanticRun {
        let range: NSRange
        let kind: MarkdownAccessibilityElementSpec.Kind
        let imageLabel: String?
    }

    private static func appendSpecs(
        for paragraphRange: NSRange,
        in text: NSAttributedString,
        to specs: inout [MarkdownAccessibilityElementSpec]
    ) {
        guard trimmedRange(of: paragraphRange, in: text) != nil else { return }

        let runs = semanticRuns(in: paragraphRange, of: text)
        guard !runs.isEmpty else {
            appendTextSpec(for: paragraphRange, in: text, to: &specs)
            return
        }

        var segmentStart = paragraphRange.location
        for run in runs {
            guard run.range.location >= segmentStart else { continue }

            if run.range.location > segmentStart {
                appendTextSpec(
                    for: NSRange(location: segmentStart, length: run.range.location - segmentStart),
                    in: text,
                    to: &specs,
                    requireLetterOrDigit: true
                )
            }

            appendRunSpec(run, in: text, to: &specs)
            segmentStart = run.range.location + run.range.length
        }

        let paragraphEnd = paragraphRange.location + paragraphRange.length
        if segmentStart < paragraphEnd {
            appendTextSpec(
                for: NSRange(location: segmentStart, length: paragraphEnd - segmentStart),
                in: text,
                to: &specs,
                requireLetterOrDigit: true
            )
        }
    }

    private static func semanticRuns(in range: NSRange, of text: NSAttributedString) -> [SemanticRun] {
        var runs: [SemanticRun] = []

        text.enumerateAttribute(MarkdownAttribute.headingLevel, in: range) { value, runRange, _ in
            guard let level = value as? Int else { return }
            runs.append(SemanticRun(range: runRange, kind: .heading(level: level), imageLabel: nil))
        }
        text.enumerateAttribute(.link, in: range) { value, runRange, _ in
            let url = value as? URL ?? (value as? String).flatMap(URL.init(string:))
            guard let url else { return }
            runs.append(SemanticRun(range: runRange, kind: .link(url), imageLabel: nil))
        }
        text.enumerateAttribute(.attachment, in: range) { value, runRange, _ in
            guard let attachment = value as? MarkdownImageAttachment else { return }
            let label = attachment.accessibilityLabel.flatMap { $0.isEmpty ? nil : $0 } ?? "Image"
            runs.append(SemanticRun(range: runRange, kind: .image, imageLabel: label))
        }

        return runs.sorted { $0.range.location < $1.range.location }
    }

    private static func appendRunSpec(
        _ run: SemanticRun,
        in text: NSAttributedString,
        to specs: inout [MarkdownAccessibilityElementSpec]
    ) {
        let label: String
        let announcement: String?

        switch run.kind {
        case .image:
            label = run.imageLabel ?? "Image"
            announcement = nil
        case .heading:
            guard let visible = trimmedRange(of: run.range, in: text) else { return }
            label = (text.string as NSString).substring(with: visible)
            announcement = nil
        case .link:
            guard let visible = trimmedRange(of: run.range, in: text) else { return }
            label = (text.string as NSString).substring(with: visible)
            // Links announce their list context even mid-item.
            announcement = listAnnouncement(in: text, at: run.range.location, requireStart: false)
        case .text:
            return
        }

        specs.append(MarkdownAccessibilityElementSpec(
            kind: run.kind,
            label: label,
            range: trimmedRange(of: run.range, in: text) ?? run.range,
            listAnnouncement: announcement
        ))
    }

    private static func appendTextSpec(
        for range: NSRange,
        in text: NSAttributedString,
        to specs: inout [MarkdownAccessibilityElementSpec],
        requireLetterOrDigit: Bool = false
    ) {
        guard let visible = trimmedRange(of: range, in: text) else { return }
        let label = (text.string as NSString).substring(with: visible)

        if requireLetterOrDigit, label.rangeOfCharacter(from: .alphanumerics) == nil {
            return
        }

        specs.append(MarkdownAccessibilityElementSpec(
            kind: .text,
            label: label,
            range: visible,
            listAnnouncement: listAnnouncement(in: text, at: visible.location, requireStart: true)
        ))
    }

    // MARK: - List context

    private static func listAnnouncement(
        in text: NSAttributedString,
        at position: Int,
        requireStart: Bool
    ) -> String? {
        guard position < text.length else { return nil }

        var numberRun = NSRange()
        let fullRange = NSRange(location: 0, length: text.length)
        guard let number = MarkdownAttributeValue.intValue(from: text.attribute(
            MarkdownAttribute.listItemNumber,
            at: position,
            longestEffectiveRange: &numberRun,
            in: fullRange
        )) else {
            return nil
        }
        var depthRun = numberRun
        let depth = MarkdownAttributeValue.intValue(from: text.attribute(
            MarkdownAttribute.listDepth,
            at: position,
            longestEffectiveRange: &depthRun,
            in: fullRange
        )) ?? 0
        let type = MarkdownAttributeValue.intValue(
            from: text.attribute(MarkdownAttribute.listType, at: position, effectiveRange: nil)
        )

        if requireStart {
            // Only the first segment of a list item announces its position:
            // the item's first visible character must be at, or just before,
            // this position. The item's
            // extent is where BOTH number and depth are constant — number
            // alone merges across nesting levels (outer item 1 / inner item
            // 1 are adjacent equal values), depth alone merges siblings.
            let itemRange = NSIntersectionRange(numberRun, depthRun)
            let firstVisible = trimmedRange(of: itemRange, in: text)?.location ?? itemRange.location
            if position > firstVisible + 1 {
                return nil
            }
        }

        let prefix = depth > 0 ? "nested " : ""
        if type == ListType.ordered.rawValue {
            return "\(prefix)list item \(number)"
        }
        return "\(prefix)bullet point"
    }

    // MARK: - Trimming

    private static func trimmedRange(of range: NSRange, in text: NSAttributedString) -> NSRange? {
        let string = text.string as NSString
        var start = range.location
        var end = range.location + range.length

        while start < end, isSkippable(string.character(at: start)) {
            start += 1
        }
        while end > start, isSkippable(string.character(at: end - 1)) {
            end -= 1
        }

        guard end > start else { return nil }
        return NSRange(location: start, length: end - start)
    }

    private static func isSkippable(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        return skippable.contains(scalar)
    }
}
