import UIKit

/// Generates semantic HTML with inline styles from the rendered attributed
/// string by walking the custom `MarkdownAttribute` keys. Used by Copy to
/// put a rich `public.html` flavor on the pasteboard alongside plain text.
///
/// The system attributed-string HTML exporter is deliberately not used: it
/// drops image URLs, loses list markers and block chrome (drawn by
/// decoration views, absent from the text), and emits unstable Apple CSS.
///
/// Hard line breaks (U+2028 within a paragraph) emit `<br>`.
enum MarkdownHTMLGenerator {
    // Fixed values not driven by the style config.
    private enum Fixed {
        static let blockquotePaddingVertical = "8px"
        static let blockquoteBorderRadiusCorners = "border-start-end-radius: 8px; border-end-end-radius: 8px"
        static let blockquoteNestedMargin = "8px 0 0 0"
        static let blockquoteParagraphMargin = "0 0 4px 0"
        static let inlineImageHeight = "1.2em"
        static let inlineImageVerticalAlign = "-0.2em"
        static let codePadding = "2px 4px"
        static let codeBorderRadius = "4px"
        static let codeFontSize = "1em"
        static let monospaceFamily = "Menlo, Monaco, Consolas, monospace"
    }

    static func generateHTML(
        from attributedText: NSAttributedString,
        in range: NSRange,
        config: MarkdownStyleConfig,
        isRTL: Bool = false
    ) -> String {
        guard range.location != NSNotFound,
              range.length > 0,
              range.location < attributedText.length
        else {
            return "<html></html>"
        }
        let clamped = NSRange(
            location: range.location,
            length: min(range.length, attributedText.length - range.location)
        )
        let text = attributedText.attributedSubstring(from: clamped)
        guard text.length > 0 else { return "<html></html>" }

        let styles = CachedStyles(config: config)
        var state = State()
        var html = ""

        if isRTL {
            html += "<html dir=\"rtl\"><div dir=\"rtl\" style=\"direction: rtl; text-align: right;\">"
        } else {
            html += "<html>"
        }

        for paragraph in collectParagraphs(in: text) {
            process(paragraph, in: text, into: &html, styles: styles, state: &state)
        }

        closeCodeBlockIfOpen(&html, state: &state, styles: styles)
        closeAllBlockquotes(&html, state: &state)
        closeListsIfOpen(&html, state: &state)

        if isRTL {
            html += "</div>"
        }
        html += "</html>"
        return html
    }

    // MARK: - Paragraph classification

    private enum ParagraphType: Equatable {
        case normal
        case heading(Int)
        case codeBlock
        case blockquote(depth: Int)
        case list(ListParagraph)
    }

    private struct ListParagraph: Equatable {
        let depth: Int
        let ordered: Bool
        /// Non-nil for the paragraph anchoring a task-list item.
        let taskChecked: Bool?
    }

    private struct Paragraph {
        let range: NSRange
        let type: ParagraphType
    }

    private struct State {
        var inCodeBlock = false
        var codeBlockLines: [String] = []
        var blockquoteDepth = -1
        var previousWasBlockquote = false
        var openListOrdered: [Bool] = []
        var listDepth = -1
    }

    private static func collectParagraphs(in text: NSAttributedString) -> [Paragraph] {
        let string = text.string as NSString
        var paragraphs: [Paragraph] = []
        var index = 0

        while index < string.length {
            let searchRange = NSRange(location: index, length: string.length - index)
            let newline = string.range(of: "\n", options: [], range: searchRange)
            let lineEnd = newline.location == NSNotFound ? string.length : newline.location + 1
            paragraphs.append(Paragraph(
                range: NSRange(location: index, length: lineEnd - index),
                type: paragraphType(at: index, in: text)
            ))
            index = lineEnd
        }
        return paragraphs
    }

    private static func paragraphType(at index: Int, in text: NSAttributedString) -> ParagraphType {
        let attrs = text.attributes(at: index, effectiveRange: nil)

        if MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.codeBlock]) {
            return .codeBlock
        }
        if let level = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.headingLevel]) {
            return .heading(min(max(level, 1), 6))
        }
        if let depth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.blockquoteDepth]) {
            return .blockquote(depth: depth)
        }
        if let depth = MarkdownAttributeValue.intValue(from: attrs[MarkdownAttribute.listDepth]) {
            let ordered = MarkdownAttributeValue.intValue(
                from: attrs[MarkdownAttribute.listType]
            ) == ListType.ordered.rawValue
            let taskChecked = attrs[MarkdownAttribute.taskListItem].map {
                MarkdownAttributeValue.boolValue(from: $0)
            }
            return .list(ListParagraph(depth: depth, ordered: ordered, taskChecked: taskChecked))
        }
        return .normal
    }

    // MARK: - Paragraph emission

    private static func process(
        _ paragraph: Paragraph,
        in text: NSAttributedString,
        into html: inout String,
        styles: CachedStyles,
        state: inout State
    ) {
        let string = text.string as NSString
        let raw = string.substring(with: paragraph.range)
        let visible = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\n\u{200B}"))

        if visible.isEmpty, paragraph.type == .normal {
            closeAllBlockquotes(&html, state: &state)
            state.previousWasBlockquote = false
            return
        }

        var contentRange = paragraph.range
        if contentRange.length > 0, string.character(at: NSMaxRange(contentRange) - 1) == 0x0A {
            contentRange.length -= 1
        }
        let isCodeBlock = paragraph.type == .codeBlock
        let inline = inlineHTML(in: text, range: contentRange, styles: styles, isCodeBlock: isCodeBlock)

        switch paragraph.type {
        case .codeBlock:
            collectCodeBlockLine(inline, state: &state)
        case .blockquote(let depth):
            emitBlockquote(inline, depth: depth, into: &html, styles: styles, state: &state)
        case .list(let list):
            emitList(inline, list: list, into: &html, styles: styles, state: &state)
        case .heading(let level):
            emitHeading(inline, level: level, into: &html, styles: styles, state: &state)
        case .normal:
            emitParagraph(inline, into: &html, styles: styles, state: &state)
        }
    }

    private static func collectCodeBlockLine(_ line: String, state: inout State) {
        if !state.inCodeBlock {
            state.inCodeBlock = true
            state.codeBlockLines.removeAll()
        }
        state.codeBlockLines.append(line)
        state.previousWasBlockquote = false
    }

    private static func emitHeading(
        _ content: String,
        level: Int,
        into html: inout String,
        styles: CachedStyles,
        state: inout State
    ) {
        closeCodeBlockIfOpen(&html, state: &state, styles: styles)
        closeAllBlockquotes(&html, state: &state)
        closeListsIfOpen(&html, state: &state)

        let idx = level - 1
        html += "<h\(level) style=\"font-size: \(styles.headingFontSizes[idx])px; "
            + "font-weight: \(styles.headingFontWeights[idx]); "
            + "color: \(styles.headingColors[idx]); "
            + "margin: 0 0 \(styles.headingMarginBottoms[idx])px 0;\">\(content)</h\(level)>"
        state.previousWasBlockquote = false
    }

    private static func emitParagraph(
        _ content: String,
        into html: inout String,
        styles: CachedStyles,
        state: inout State
    ) {
        closeCodeBlockIfOpen(&html, state: &state, styles: styles)
        closeAllBlockquotes(&html, state: &state)
        closeListsIfOpen(&html, state: &state)

        html += "<p style=\"margin: 0 0 \(styles.paragraphMarginBottom)px 0; "
            + "color: \(styles.paragraphColor); "
            + "font-size: \(styles.paragraphFontSize)px;\">\(content)</p>"
        state.previousWasBlockquote = false
    }

    private static func emitBlockquote(
        _ content: String,
        depth: Int,
        into html: inout String,
        styles: CachedStyles,
        state: inout State
    ) {
        closeCodeBlockIfOpen(&html, state: &state, styles: styles)

        if !state.previousWasBlockquote, state.blockquoteDepth >= 0 {
            closeAllBlockquotes(&html, state: &state)
        }

        while state.blockquoteDepth > depth {
            html += "</blockquote>"
            state.blockquoteDepth -= 1
        }

        while state.blockquoteDepth < depth {
            state.blockquoteDepth += 1
            if state.blockquoteDepth == 0 {
                html += "<blockquote style=\"background-color: \(styles.blockquoteBgColor); "
                    + "border-inline-start: \(styles.blockquoteBorderWidth)px solid \(styles.blockquoteBorderColor); "
                    + "padding: \(Fixed.blockquotePaddingVertical) \(styles.blockquoteGapWidth)px; "
                    + "margin: 0 0 \(styles.blockquoteMarginBottom)px 0; "
                    + "\(Fixed.blockquoteBorderRadiusCorners);\">"
            } else {
                html += "<blockquote style=\"border-inline-start: \(styles.blockquoteBorderWidth)px solid \(styles.blockquoteBorderColor); "
                    + "padding-inline-start: \(styles.blockquoteGapWidth)px; "
                    + "margin: \(Fixed.blockquoteNestedMargin);\">"
            }
        }

        html += "<p style=\"margin: \(Fixed.blockquoteParagraphMargin); "
            + "color: \(styles.blockquoteColor); "
            + "font-size: \(styles.blockquoteFontSize)px;\">\(content)</p>"
        state.previousWasBlockquote = true
    }

    private static func emitList(
        _ content: String,
        list: ListParagraph,
        into html: inout String,
        styles: CachedStyles,
        state: inout State
    ) {
        let depth = list.depth
        let ordered = list.ordered
        closeCodeBlockIfOpen(&html, state: &state, styles: styles)
        closeAllBlockquotes(&html, state: &state)

        while state.listDepth > depth {
            html += state.openListOrdered.last == true ? "</ol>" : "</ul>"
            if !state.openListOrdered.isEmpty {
                state.openListOrdered.removeLast()
            }
            state.listDepth -= 1
        }

        if state.listDepth == depth, let last = state.openListOrdered.last, last != ordered {
            html += last ? "</ol>" : "</ul>"
            state.openListOrdered.removeLast()
            state.listDepth -= 1
        }

        while state.listDepth < depth {
            state.listDepth += 1
            let margin = state.listDepth == 0 ? "margin: 0 0 \(styles.paragraphMarginBottom)px 0; " : "margin: 0; "
            if ordered {
                html += "<ol style=\"\(margin)padding-inline-start: \(styles.listMarginLeft)px;\">"
                state.openListOrdered.append(true)
            } else {
                html += "<ul style=\"\(margin)padding-inline-start: \(styles.listMarginLeft)px; list-style-type: disc;\">"
                state.openListOrdered.append(false)
            }
        }

        // Task items hide the list marker and lead with a disabled checkbox,
        // matching GitHub's task-list markup.
        let taskListStyle = list.taskChecked != nil ? " list-style-type: none;" : ""
        let checkboxPrefix = list.taskChecked.map { checked in
            "<input type=\"checkbox\" disabled\(checked ? " checked" : "") "
                + "style=\"margin: 0 0.4em 0.1em -1.3em; vertical-align: middle;\">"
        } ?? ""
        html += "<li style=\"margin-bottom: \(styles.listMarginBottom)px; "
            + "color: \(styles.listColor); "
            + "font-size: \(styles.listFontSize)px;\(taskListStyle)\">\(checkboxPrefix)\(content)</li>"
        state.previousWasBlockquote = false
    }

    private static func closeCodeBlockIfOpen(_ html: inout String, state: inout State, styles: CachedStyles) {
        guard state.inCodeBlock else { return }
        state.inCodeBlock = false

        // iOS code blocks carry padding spacer lines; trim empty leading and
        // trailing lines but keep interior blank lines.
        var lines = state.codeBlockLines
        while lines.first?.isEmpty == true { lines.removeFirst() }
        while lines.last?.isEmpty == true { lines.removeLast() }
        state.codeBlockLines.removeAll()
        guard !lines.isEmpty else { return }

        html += "<pre dir=\"ltr\" style=\"background-color: \(styles.codeBlockBgColor); "
            + "padding: \(styles.codeBlockPadding)px; "
            + "border-radius: \(styles.codeBlockBorderRadius)px; "
            + "margin: 0 0 \(styles.codeBlockMarginBottom)px 0; "
            + "overflow-x: auto; text-align: left;\">"
            + "<code style=\"font-family: \(Fixed.monospaceFamily); "
            + "font-size: \(styles.codeBlockFontSize)px; "
            + "color: \(styles.codeBlockColor);\">"
        html += lines.joined(separator: "\n")
        html += "</code></pre>"
    }

    private static func closeAllBlockquotes(_ html: inout String, state: inout State) {
        while state.blockquoteDepth >= 0 {
            html += "</blockquote>"
            state.blockquoteDepth -= 1
        }
    }

    private static func closeListsIfOpen(_ html: inout String, state: inout State) {
        while let last = state.openListOrdered.popLast() {
            html += last ? "</ol>" : "</ul>"
        }
        state.listDepth = -1
    }

    // MARK: - Inline emission

    private static func inlineHTML(
        in text: NSAttributedString,
        range: NSRange,
        styles: CachedStyles,
        isCodeBlock: Bool
    ) -> String {
        guard range.length > 0 else { return "" }
        var html = ""
        let string = text.string as NSString

        text.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
            let content = string.substring(with: runRange)

            if let attachment = attrs[.attachment] as? MarkdownImageAttachment {
                appendImage(attachment, into: &html, styles: styles)
                return
            }
            if attrs[.attachment] != nil || content == "\u{FFFC}" {
                return
            }

            let cleaned = content
                .replacingOccurrences(of: "\u{200B}", with: "")
                .trimmingCharacters(in: .newlines)
            guard !cleaned.isEmpty else { return }

            appendStyledSegment(cleaned, attrs: attrs, into: &html, styles: styles, isCodeBlock: isCodeBlock)
        }
        return html
    }

    private static func appendImage(
        _ attachment: MarkdownImageAttachment,
        into html: inout String,
        styles: CachedStyles
    ) {
        guard !attachment.imageURL.isEmpty else { return }
        let escapedURL = escapeHTML(attachment.imageURL)

        if attachment.isInline {
            html += "<img src=\"\(escapedURL)\" style=\"height: \(Fixed.inlineImageHeight); "
                + "width: auto; vertical-align: \(Fixed.inlineImageVerticalAlign);\">"
        } else {
            html += "</p><div style=\"margin-bottom: \(styles.imageMarginBottom)px;\">"
                + "<img src=\"\(escapedURL)\" style=\"max-width: 100%; border-radius: \(styles.imageBorderRadius)px;\">"
                + "</div><p>"
        }
    }

    private static func appendStyledSegment(
        _ content: String,
        attrs: [NSAttributedString.Key: Any],
        into html: inout String,
        styles: CachedStyles,
        isCodeBlock: Bool
    ) {
        let tags = inlineTags(attrs: attrs, styles: styles, isCodeBlock: isCodeBlock)
        for tag in tags {
            html += tag.open
        }
        html += escapeHTML(content).replacingOccurrences(of: "\u{2028}", with: "<br>")
        for tag in tags.reversed() {
            html += tag.close
        }
    }

    /// Open/close tag pairs for the run's inline traits, outermost first.
    private static func inlineTags(
        attrs: [NSAttributedString.Key: Any],
        styles: CachedStyles,
        isCodeBlock: Bool
    ) -> [(open: String, close: String)] {
        let isStrong = MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.strong])
        let isEmphasis = MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.emphasis])
        let isStrikethrough = (MarkdownAttributeValue.intValue(from: attrs[.strikethroughStyle]) ?? 0) != 0
        let isUnderline = (MarkdownAttributeValue.intValue(from: attrs[.underlineStyle]) ?? 0) != 0
        let isCode = MarkdownAttributeValue.boolValue(from: attrs[MarkdownAttribute.inlineCode]) && !isCodeBlock

        let linkURL: String?
        switch attrs[.link] {
        case let url as URL: linkURL = url.absoluteString
        case let string as String: linkURL = string
        default: linkURL = nil
        }

        var tags: [(open: String, close: String)] = []
        if let linkURL {
            let open = "<a href=\"\(escapeHTML(linkURL))\" style=\"color: \(styles.linkColor); "
                + "text-decoration: \(styles.linkUnderline ? "underline" : "none");\">"
            tags.append((open: open, close: "</a>"))
        }
        if isCode {
            let open = "<code style=\"background-color: \(styles.codeBgColor); "
                + "color: \(styles.codeColor); "
                + "padding: \(Fixed.codePadding); "
                + "border-radius: \(Fixed.codeBorderRadius); "
                + "font-size: \(Fixed.codeFontSize); "
                + "font-family: \(Fixed.monospaceFamily);\">"
            tags.append((open: open, close: "</code>"))
        }
        if isStrong {
            tags.append((open: styles.strongColor.map { "<strong style=\"color: \($0);\">" } ?? "<strong>", close: "</strong>"))
        }
        if isEmphasis {
            tags.append((open: styles.emphasisColor.map { "<em style=\"color: \($0);\">" } ?? "<em>", close: "</em>"))
        }
        if isUnderline, linkURL == nil {
            tags.append((open: "<u>", close: "</u>"))
        }
        if isStrikethrough {
            tags.append((open: "<s>", close: "</s>"))
        }
        return tags
    }

    // MARK: - Styles

    private struct CachedStyles {
        let paragraphColor: String
        let paragraphFontSize: Int
        let paragraphMarginBottom: Int

        let codeBlockColor: String
        let codeBlockBgColor: String
        let codeBlockFontSize: Int
        let codeBlockPadding: Int
        let codeBlockBorderRadius: Int
        let codeBlockMarginBottom: Int

        let codeColor: String
        let codeBgColor: String

        let blockquoteColor: String
        let blockquoteBgColor: String
        let blockquoteBorderColor: String
        let blockquoteBorderWidth: Int
        let blockquoteGapWidth: Int
        let blockquoteMarginBottom: Int
        let blockquoteFontSize: Int

        let listColor: String
        let listFontSize: Int
        let listMarginBottom: Int
        let listMarginLeft: Int

        let linkColor: String
        let linkUnderline: Bool

        let strongColor: String?
        let emphasisColor: String?

        let imageMarginBottom: Int
        let imageBorderRadius: Int

        let headingFontSizes: [Int]
        let headingFontWeights: [String]
        let headingColors: [String]
        let headingMarginBottoms: [Int]

        init(config: MarkdownStyleConfig) {
            let bodySize = Int(UIFont.preferredFont(forTextStyle: .body).pointSize)

            paragraphColor = cssColor(config.paragraph.foregroundColor)
            paragraphFontSize = config.paragraph.font.map { Int($0.pointSize) } ?? bodySize
            paragraphMarginBottom = Int(config.paragraph.marginBottom ?? 0)

            codeBlockColor = cssColor(config.codeBlock.foregroundColor)
            codeBlockBgColor = cssColor(config.codeBlock.backgroundColor)
            codeBlockFontSize = config.codeBlock.font.map { Int($0.pointSize) } ?? bodySize
            codeBlockPadding = Int(config.codeBlock.padding ?? 0)
            codeBlockBorderRadius = Int(config.codeBlock.borderRadius ?? 0)
            codeBlockMarginBottom = Int(config.codeBlock.marginBottom ?? 0)

            codeColor = cssColor(config.code.foregroundColor)
            codeBgColor = cssColor(config.code.backgroundColor)

            blockquoteColor = cssColor(config.blockquote.foregroundColor)
            blockquoteBgColor = cssColor(config.blockquote.backgroundColor)
            blockquoteBorderColor = cssColor(config.blockquote.borderColor)
            blockquoteBorderWidth = Int(config.blockquote.borderWidth ?? 0)
            blockquoteGapWidth = Int(config.blockquote.gapWidth ?? 0)
            blockquoteMarginBottom = Int(config.blockquote.marginBottom ?? 0)
            blockquoteFontSize = config.blockquote.font.map { Int($0.pointSize) } ?? bodySize

            listColor = cssColor(config.list.foregroundColor)
            listFontSize = config.list.font.map { Int($0.pointSize) } ?? bodySize
            listMarginBottom = Int(config.list.marginBottom ?? 0)
            listMarginLeft = Int(config.list.marginLeft ?? 24)

            linkColor = cssColor(config.link.foregroundColor)
            linkUnderline = config.link.underline ?? true

            strongColor = config.strong.foregroundColor.map(cssColor)
            emphasisColor = config.emphasis.foregroundColor.map(cssColor)

            imageMarginBottom = Int(config.image.marginBottom ?? 0)
            imageBorderRadius = Int(config.image.borderRadius ?? 0)

            let headings = [
                config.heading1, config.heading2, config.heading3,
                config.heading4, config.heading5, config.heading6
            ]
            headingFontSizes = headings.map { $0.font.map { Int($0.pointSize) } ?? bodySize }
            headingFontWeights = headings.map { heading in
                let isBold = heading.font?.fontDescriptor.symbolicTraits.contains(.traitBold) ?? true
                return isBold ? "700" : "normal"
            }
            headingColors = headings.map { cssColor($0.foregroundColor) }
            headingMarginBottoms = headings.map { Int($0.marginBottom ?? 0) }
        }
    }

    // MARK: - Helpers

    private static func cssColor(_ color: UIColor?) -> String {
        guard let color else { return "inherit" }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "inherit" }

        let redByte = Int(round(min(max(red, 0), 1) * 255))
        let greenByte = Int(round(min(max(green, 0), 1) * 255))
        let blueByte = Int(round(min(max(blue, 0), 1) * 255))
        if alpha < 1 {
            let alphaString = String(format: "%.2f", alpha)
            return "rgba(\(redByte), \(greenByte), \(blueByte), \(alphaString))"
        }
        return String(format: "#%02X%02X%02X", redByte, greenByte, blueByte)
    }

    private static func escapeHTML(_ text: String) -> String {
        guard text.contains(where: { "&<>\"'".contains($0) }) else { return text }
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
