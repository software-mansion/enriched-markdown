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

        // Headings may span multiple attribute runs.
        var currentHeadingLevel: Int?
        var headingContent = ""

        func flushHeading() {
            guard let level = currentHeadingLevel, !headingContent.isEmpty else {
                currentHeadingLevel = nil
                headingContent = ""
                return
            }
            ensureBlankLine(&result)
            result += String(repeating: "#", count: level) + " " + headingContent + "\n"
            currentHeadingLevel = nil
            headingContent = ""
            state.needsBlankLine = true
        }

        attributedText.enumerateAttributes(in: clamped, options: []) { attrs, attrRange, _ in
            let text = (attributedText.string as NSString).substring(with: attrRange)
            guard !text.isEmpty else { return }

            // Images and thematic breaks
            if let attachment = attrs[.attachment] as? MarkdownImageAttachment {
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
                return
            }

            if attrs[.attachment] is ThematicBreakAttachment {
                ensureBlankLine(&result)
                result += "---\n"
                state.needsBlankLine = true
                state.blockquoteDepth = -1
                state.listDepth = -1
                return
            }

            if text == "\u{FFFC}" {
                return
            }

            // Newline runs (paragraph breaks and margin/padding spacers).
            // Checked before the code-block branch so code-block padding
            // spacers never open or close fences.
            if text.allSatisfy({ $0 == "\n" }) {
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
                return
            }

            // Headings
            if let level = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.headingLevel]) {
                if level != currentHeadingLevel {
                    flushHeading()
                    currentHeadingLevel = level
                }
                headingContent += text.trimmingCharacters(in: .newlines)
                return
            } else if currentHeadingLevel != nil {
                flushHeading()
            }

            // Code blocks
            if MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.codeBlock]) {
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
                return
            }

            // Blockquotes
            let currentBlockquoteDepth = MarkdownAttributeValue.intValue(
                from: attrs[MarkdownAttribute.blockquoteDepth]
            ) ?? -1
            var blockquotePrefix: String?

            if currentBlockquoteDepth >= 0 {
                blockquotePrefix = Self.blockquotePrefix(depth: currentBlockquoteDepth)
                state.blockquoteDepth = currentBlockquoteDepth
            } else if state.blockquoteDepth >= 0 {
                ensureBlankLine(&result)
                state.blockquoteDepth = -1
            }

            // Lists
            let currentListDepth = MarkdownAttributeValue.intValue(
                from: attrs[MarkdownAttribute.listDepth]
            )

            if let currentListDepth {
                state.listDepth = currentListDepth
            } else if state.listDepth >= 0 {
                ensureBlankLine(&result)
                state.listDepth = -1
            }

            // Inline formatting. Hard line breaks render as U+2028; map them
            // back to newlines before wrapping.
            let segmentText = text.replacingOccurrences(of: "\u{2028}", with: "\n")
            var segment = applyInlineFormatting(segmentText, traits: InlineTraits(attrs: attrs))

            // Block prefixes at line start
            if isAtLineStart(result) {
                var prefix = ""

                if let currentListDepth, !text.hasPrefix("\n") {
                    let isOrdered = MarkdownAttributeValue.intValue(
                        from: attrs[MarkdownAttribute.listType]
                    ) == ListType.ordered.rawValue
                    let itemNumber = MarkdownAttributeValue.intValue(
                        from: attrs[MarkdownAttribute.listItemNumber]
                    ) ?? 1
                    prefix += listPrefix(depth: currentListDepth, isOrdered: isOrdered, itemNumber: itemNumber)
                }

                if let blockquotePrefix {
                    prefix = blockquotePrefix + prefix
                }

                segment = prefix + segment
            }

            if state.needsBlankLine, !result.isEmpty {
                ensureBlankLine(&result)
                state.needsBlankLine = false
            }

            result += segment
        }

        flushHeading()

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
