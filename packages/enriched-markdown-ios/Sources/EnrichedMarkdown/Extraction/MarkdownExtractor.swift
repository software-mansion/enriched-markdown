import UIKit

/// Reconstructs markdown source from a rendered `NSAttributedString`.
///
/// The renderers strip the original markdown syntax, so a partial selection is
/// reverse-engineered from the custom `MarkdownAttribute` keys the renderers
/// leave behind. Block chrome (list markers, blockquote bars, code-block
/// backgrounds) lives in decoration views rather than the text itself, which is
/// why prefixes are derived from attributes instead of the string content.
///
/// Reconstruction is CommonMark-equivalent, not byte-identical: soft breaks
/// come back as spaces and heading text loses inline markers. A selection that
/// covers the whole document therefore returns the original source verbatim.
enum MarkdownExtractor {
    /// Markdown for `range`, using `sourceMarkdown` verbatim when the range
    /// covers the entire rendered document.
    static func markdown(
        for range: NSRange,
        in attributedText: NSAttributedString,
        sourceMarkdown: String?
    ) -> String? {
        guard let clamped = clampedRange(range, in: attributedText) else { return nil }

        if let sourceMarkdown, isFullSelection(clamped, in: attributedText) {
            return sourceMarkdown
        }
        return extractMarkdown(from: attributedText, in: clamped)
    }

    /// Best-effort markdown reconstruction for a partial selection.
    static func extractMarkdown(from attributedText: NSAttributedString, in range: NSRange) -> String? {
        guard let clamped = clampedRange(range, in: attributedText) else { return nil }

        var result = ""
        var state = ExtractionState()

        attributedText.enumerateAttributes(in: clamped, options: []) { attrs, attrRange, _ in
            let text = (attributedText.string as NSString).substring(with: attrRange)
            guard !text.isEmpty else { return }
            appendRun(text, attrs: attrs, to: &result, state: &state)
        }

        flushHeading(&result, state: &state)

        return result.isEmpty ? nil : result
    }

    /// http(s) URLs of image attachments within `range`, in document order.
    static func imageURLs(in attributedText: NSAttributedString, range: NSRange) -> [String] {
        guard let clamped = clampedRange(range, in: attributedText) else { return [] }

        var urls: [String] = []
        attributedText.enumerateAttribute(.attachment, in: clamped, options: []) { value, _, _ in
            guard let attachment = value as? MarkdownImageAttachment else { return }
            let url = attachment.imageURL
            let lowercased = url.lowercased()
            if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") {
                urls.append(url)
            }
        }
        return urls
    }
}

private extension MarkdownExtractor {
    struct ExtractionState {
        var blockquoteDepth = -1
        var listDepth = -1
        var needsBlankLine = false
        // Headings may span multiple attribute runs.
        var headingLevel: Int?
        var headingContent = ""
    }

    /// Appends one attribute run, dispatching on the run's block kind.
    static func appendRun(
        _ text: String,
        attrs: [NSAttributedString.Key: Any],
        to result: inout String,
        state: inout ExtractionState
    ) {
        if let attachment = attrs[.attachment] as? MarkdownImageAttachment {
            appendImage(attachment, to: &result, state: &state)
            return
        }

        if attrs[.attachment] is ThematicBreakAttachment {
            appendThematicBreak(to: &result, state: &state)
            return
        }

        if text == "\u{FFFC}" {
            return
        }

        // Newline runs are checked before the code-block branch so code-block
        // padding spacers never open or close fences.
        if text.allSatisfy({ $0 == "\n" }) {
            appendNewlineRun(attrs: attrs, to: &result, state: &state)
            return
        }

        if let level = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.headingLevel]) {
            accumulateHeading(text, level: level, to: &result, state: &state)
            return
        }
        flushHeading(&result, state: &state)

        if MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.codeBlock]) {
            appendCodeBlockRun(text, to: &result, state: &state)
            return
        }

        appendInlineRun(text, attrs: attrs, to: &result, state: &state)
    }

    static func appendImage(
        _ attachment: MarkdownImageAttachment,
        to result: inout String,
        state: inout ExtractionState
    ) {
        guard !attachment.imageURL.isEmpty else { return }
        if attachment.isInline {
            result += "![image](\(attachment.imageURL))"
        } else {
            ensureBlankLine(&result)
            result += "![image](\(attachment.imageURL))\n"
            state.needsBlankLine = true
            state.blockquoteDepth = -1
            state.listDepth = -1
        }
    }

    static func appendThematicBreak(to result: inout String, state: inout ExtractionState) {
        ensureBlankLine(&result)
        result += "---\n"
        state.needsBlankLine = true
        state.blockquoteDepth = -1
        state.listDepth = -1
    }

    /// Paragraph breaks and margin/padding spacers.
    static func appendNewlineRun(
        attrs: [NSAttributedString.Key: Any],
        to result: inout String,
        state: inout ExtractionState
    ) {
        let inBlockquote = MarkdownAttributeValue.intValue(
            from: attrs[MarkdownAttribute.blockquoteDepth]
        ) != nil
        let inList = MarkdownAttributeValue.intValue(
            from: attrs[MarkdownAttribute.listDepth]
        ) != nil

        if !inBlockquote, state.blockquoteDepth >= 0 {
            ensureBlankLine(&result)
            state.blockquoteDepth = -1
            return
        }

        if !inList, state.listDepth >= 0 {
            ensureBlankLine(&result)
            state.listDepth = -1
            return
        }

        if inBlockquote || inList {
            if !result.hasSuffix("\n") {
                result += "\n"
            }
            return
        }

        ensureBlankLine(&result)
    }

    static func accumulateHeading(
        _ text: String,
        level: Int,
        to result: inout String,
        state: inout ExtractionState
    ) {
        if level != state.headingLevel {
            flushHeading(&result, state: &state)
            state.headingLevel = level
        }
        state.headingContent += text.trimmingCharacters(in: .newlines)
    }

    static func flushHeading(_ result: inout String, state: inout ExtractionState) {
        defer {
            state.headingLevel = nil
            state.headingContent = ""
        }
        guard let level = state.headingLevel, !state.headingContent.isEmpty else { return }
        ensureBlankLine(&result)
        result += String(repeating: "#", count: level) + " " + state.headingContent + "\n"
        state.needsBlankLine = true
    }

    static func appendCodeBlockRun(_ text: String, to result: inout String, state: inout ExtractionState) {
        if state.needsBlankLine {
            ensureBlankLine(&result)
            state.needsBlankLine = false
        }

        if result.isEmpty || result.hasSuffix("\n\n") {
            result += "```\n"
        }

        result += text

        if text.hasSuffix("\n") {
            result += "```\n"
            state.needsBlankLine = true
        }
    }

    static func appendInlineRun(
        _ text: String,
        attrs: [NSAttributedString.Key: Any],
        to result: inout String,
        state: inout ExtractionState
    ) {
        let blockquoteDepth = MarkdownAttributeValue.intValue(
            from: attrs[MarkdownAttribute.blockquoteDepth]
        ) ?? -1
        if blockquoteDepth >= 0 {
            state.blockquoteDepth = blockquoteDepth
        } else if state.blockquoteDepth >= 0 {
            ensureBlankLine(&result)
            state.blockquoteDepth = -1
        }

        let listDepth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth])
        if let listDepth {
            state.listDepth = listDepth
        } else if state.listDepth >= 0 {
            ensureBlankLine(&result)
            state.listDepth = -1
        }

        // Hard line breaks render as U+2028; map them back to newlines
        // before wrapping.
        let segmentText = text.replacingOccurrences(of: "\u{2028}", with: "\n")
        var segment = applyInlineFormatting(segmentText, traits: InlineTraits(attrs: attrs))

        if isAtLineStart(result) {
            segment = linePrefix(for: text, attrs: attrs, blockquoteDepth: blockquoteDepth, listDepth: listDepth)
                + segment
        }

        if state.needsBlankLine, !result.isEmpty {
            ensureBlankLine(&result)
            state.needsBlankLine = false
        }

        result += segment
    }

    /// Block prefixes (list marker, blockquote bars) at the start of a line.
    static func linePrefix(
        for text: String,
        attrs: [NSAttributedString.Key: Any],
        blockquoteDepth: Int,
        listDepth: Int?
    ) -> String {
        var prefix = ""

        if let listDepth, !text.hasPrefix("\n") {
            let isOrdered = MarkdownAttributeValue.intValue(
                from: attrs[MarkdownAttribute.listType]
            ) == ListType.ordered.rawValue
            let itemNumber = MarkdownAttributeValue.intValue(
                from: attrs[MarkdownAttribute.listItemNumber]
            ) ?? 1
            prefix += listPrefix(depth: listDepth, isOrdered: isOrdered, itemNumber: itemNumber)
        }

        if blockquoteDepth >= 0 {
            prefix = blockquotePrefix(depth: blockquoteDepth) + prefix
        }

        return prefix
    }

    struct InlineTraits {
        let isInlineCode: Bool
        let isStrong: Bool
        let isEmphasis: Bool
        let isStrikethrough: Bool
        let isUnderline: Bool
        let linkURL: String?

        init(attrs: [NSAttributedString.Key: Any]) {
            isInlineCode = MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.inlineCode])
            isStrong = MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.strong])
            isEmphasis = MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.emphasis])
            isStrikethrough = (MarkdownAttributeValue.intValue(from: attrs[.strikethroughStyle]) ?? 0) != 0
            isUnderline = (MarkdownAttributeValue.intValue(from: attrs[.underlineStyle]) ?? 0) != 0

            switch attrs[.link] {
            case let url as URL:
                linkURL = url.absoluteString
            case let string as String:
                linkURL = string
            default:
                linkURL = nil
            }
        }
    }

    static func clampedRange(_ range: NSRange, in attributedText: NSAttributedString) -> NSRange? {
        guard range.location != NSNotFound,
              range.location >= 0,
              range.length > 0,
              range.location < attributedText.length
        else {
            return nil
        }
        return NSRange(
            location: range.location,
            length: min(range.length, attributedText.length - range.location)
        )
    }

    /// A selection is "full" when it starts at the beginning and any excluded
    /// tail is whitespace-only (themes append 1–2 trailing margin spacers that
    /// Select All may skip).
    static func isFullSelection(_ range: NSRange, in attributedText: NSAttributedString) -> Bool {
        guard range.location == 0 else { return false }
        let tail = (attributedText.string as NSString).substring(from: NSMaxRange(range))
        return tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func ensureBlankLine(_ result: inout String) {
        guard !result.isEmpty, !result.hasSuffix("\n\n") else { return }
        result += result.hasSuffix("\n") ? "\n" : "\n\n"
    }

    static func isAtLineStart(_ result: String) -> Bool {
        result.isEmpty || result.hasSuffix("\n")
    }

    /// Depth 0 = "> ", depth 1 = "> > ", etc.
    static func blockquotePrefix(depth: Int) -> String {
        String(repeating: "> ", count: depth + 1)
    }

    static func listPrefix(depth: Int, isOrdered: Bool, itemNumber: Int) -> String {
        let indent = String(repeating: " ", count: depth * 2)
        let marker = isOrdered ? "\(itemNumber)." : "-"
        return "\(indent)\(marker) "
    }

    static func applyInlineFormatting(_ text: String, traits: InlineTraits) -> String {
        var result = text

        // Innermost first
        if traits.isInlineCode, traits.linkURL == nil {
            result = "`\(result)`"
        }
        if traits.isStrikethrough {
            result = "~~\(result)~~"
        }
        if traits.isUnderline, traits.linkURL == nil {
            result = "<u>\(result)</u>"
        }
        if traits.isEmphasis {
            result = "*\(result)*"
        }
        if traits.isStrong {
            result = "**\(result)**"
        }
        if let linkURL = traits.linkURL {
            result = "[\(result)](\(linkURL))"
        }

        return result
    }
}
