import UIKit

/// A VoiceOver element description derived from the rendered attributed
/// string, with every spoken string already resolved. Pure data so the
/// segmentation logic is unit-testable; frames are resolved lazily by
/// `MarkdownAccessibilityElement` at query time.
struct MarkdownAccessibilityElementSpec: Equatable {
    enum Kind: Equatable {
        case text
        case link(URL)
        /// `link` is the wrapping link's target for `[![alt](img)](url)`.
        case image(link: URL?)
        /// One fenced block; the label is the code itself.
        case codeBlock(copyAction: String)
        case tableRow(offset: CGFloat, height: CGFloat, isHeader: Bool)
    }

    let kind: Kind
    let label: String
    /// Trimmed character range used for frame calculation.
    let range: NSRange
    /// Set for text and link segments inside a heading.
    let headingLevel: Int?
    /// Spoken after the label: list position and/or blockquote context.
    let value: String?

    /// Target URL for elements that activate a link press.
    var linkURL: URL? {
        switch kind {
        case .link(let url):
            return url
        case .image(let link):
            return link
        case .text, .codeBlock, .tableRow:
            return nil
        }
    }
}

/// Segments the rendered attributed string into VoiceOver elements: one
/// element per fenced code block, otherwise split into paragraphs, drop
/// spacer-only paragraphs, and carve link/image/attachment runs into their
/// own elements with plain text between them. Headings, lists, and
/// blockquotes are context read per segment, not runs of their own, so a
/// link inside a heading stays navigable and keeps the heading trait.
struct MarkdownAccessibilityElementBuilder {
    static func specs(
        for text: NSAttributedString,
        labels: MarkdownAccessibilityLabels = .default
    ) -> [MarkdownAccessibilityElementSpec] {
        var builder = MarkdownAccessibilityElementBuilder(text: text, labels: labels)
        return builder.build()
    }

    /// Zero-width space (list marker anchors) and line separator join plain
    /// whitespace as "invisible" for trimming; U+FFFC attachment characters
    /// count as content.
    private static let skippable: CharacterSet = {
        var set = CharacterSet.whitespacesAndNewlines
        set.insert(charactersIn: "\u{200B}\u{2028}")
        return set
    }()

    private static let attachmentCharacter: String = "\u{FFFC}"

    private let text: NSAttributedString
    private let string: NSString
    private let labels: MarkdownAccessibilityLabels
    private var specs: [MarkdownAccessibilityElementSpec] = []

    private init(text: NSAttributedString, labels: MarkdownAccessibilityLabels) {
        self.text = text
        self.string = text.string as NSString
        self.labels = labels
    }

    private mutating func build() -> [MarkdownAccessibilityElementSpec] {
        var cursor = 0
        while cursor < string.length {
            if let block = codeBlockRange(at: cursor) {
                appendCodeBlockSpec(for: block)
                cursor = block.location + block.length
                continue
            }

            let searchRange = NSRange(location: cursor, length: string.length - cursor)
            let newline = string.range(of: "\n", options: [], range: searchRange)
            let paragraphEnd = newline.location == NSNotFound ? string.length : newline.location + 1
            appendParagraphSpecs(for: NSRange(location: cursor, length: paragraphEnd - cursor))
            cursor = paragraphEnd
        }
        return specs
    }

    // MARK: - Code blocks

    /// The full range of the fenced code block that starts at `position`,
    /// spacer lines included.
    private func codeBlockRange(at position: Int) -> NSRange? {
        guard MarkdownAttributeValue.boolValue(from: attribute(MarkdownAttribute.codeBlock, at: position)) else {
            return nil
        }
        var range = NSRange()
        _ = text.attribute(
            MarkdownAttribute.codeBlock,
            at: position,
            longestEffectiveRange: &range,
            in: NSRange(location: position, length: string.length - position)
        )
        return range
    }

    private mutating func appendCodeBlockSpec(for range: NSRange) {
        guard let (visible, code) = visibleText(in: range) else { return }
        specs.append(MarkdownAccessibilityElementSpec(
            kind: .codeBlock(copyAction: labels.codeBlock.copy),
            label: code,
            range: visible,
            headingLevel: nil,
            value: nil
        ))
    }

    // MARK: - Paragraph segmentation

    private enum SemanticRun {
        case image(NSRange, label: String, link: URL?)
        /// A plugin attachment that carries its own spoken label.
        case attachment(NSRange, label: String)
        case table(NSRange, TableAttachment)
        case link(NSRange, URL)

        var range: NSRange {
            switch self {
            case .image(let range, _, _), .attachment(let range, _), .table(let range, _), .link(let range, _):
                return range
            }
        }
    }

    private mutating func appendParagraphSpecs(for paragraphRange: NSRange) {
        guard trimmedRange(of: paragraphRange) != nil else { return }

        let runs = semanticRuns(in: paragraphRange)
        guard !runs.isEmpty else {
            appendTextSpec(for: paragraphRange)
            return
        }

        var segmentStart = paragraphRange.location
        for run in runs {
            guard run.range.location >= segmentStart else { continue }

            if run.range.location > segmentStart {
                appendTextSpec(
                    for: NSRange(location: segmentStart, length: run.range.location - segmentStart),
                    requireLetterOrDigit: true
                )
            }

            appendRunSpec(run)
            segmentStart = run.range.location + run.range.length
        }

        let paragraphEnd = paragraphRange.location + paragraphRange.length
        if segmentStart < paragraphEnd {
            appendTextSpec(
                for: NSRange(location: segmentStart, length: paragraphEnd - segmentStart),
                requireLetterOrDigit: true
            )
        }
    }

    /// Attachments that stand on their own (images, tables, labelled plugin
    /// attachments) plus link runs carved around them, in document order.
    private func semanticRuns(in range: NSRange) -> [SemanticRun] {
        var attachments: [SemanticRun] = []
        text.enumerateAttribute(.attachment, in: range) { value, runRange, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            if let image = attachment as? MarkdownImageAttachment {
                attachments.append(.image(
                    runRange,
                    label: image.accessibilityLabel ?? labels.image.fallback,
                    link: url(from: attribute(.link, at: runRange.location))
                ))
            } else if let table = attachment as? TableAttachment {
                attachments.append(.table(runRange, table))
            } else if let label = attachment.accessibilityLabel, !label.isEmpty {
                attachments.append(.attachment(runRange, label: label))
            }
        }

        let holes = attachments.map(\.range)
        var links: [SemanticRun] = []
        text.enumerateAttribute(.link, in: range) { value, runRange, _ in
            guard let url = url(from: value) else { return }
            for piece in Self.subtracting(holes, from: runRange) {
                links.append(.link(piece, url))
            }
        }

        return (attachments + links).sorted { $0.range.location < $1.range.location }
    }

    private func url(from value: Any?) -> URL? {
        value as? URL ?? (value as? String).flatMap(URL.init(string:))
    }

    /// The parts of `range` not covered by `holes` (in document order).
    private static func subtracting(_ holes: [NSRange], from range: NSRange) -> [NSRange] {
        var pieces: [NSRange] = []
        var start = range.location
        let end = range.location + range.length
        for hole in holes where TextLayoutHelpers.rangesIntersect(hole, range) {
            if hole.location > start {
                pieces.append(NSRange(location: start, length: hole.location - start))
            }
            start = max(start, hole.location + hole.length)
        }
        if start < end {
            pieces.append(NSRange(location: start, length: end - start))
        }
        return pieces
    }

    private mutating func appendRunSpec(_ run: SemanticRun) {
        switch run {
        case .table(let range, let table):
            appendTableRowSpecs(for: table, range: range)
        case .image(let range, let label, let link):
            specs.append(MarkdownAccessibilityElementSpec(
                kind: .image(link: link),
                label: label,
                range: range,
                headingLevel: nil,
                value: nil
            ))
        case .attachment(let range, let label):
            specs.append(contextSpec(kind: .text, label: label, range: range, requireListStart: false))
        case .link(let range, let url):
            // Links announce their list context even mid-item.
            guard let (visible, label) = visibleText(in: range) else { return }
            specs.append(contextSpec(kind: .link(url), label: label, range: visible, requireListStart: false))
        }
    }

    /// One element per table row: "Row {n}: {cells}", the header row
    /// carrying the header trait. Frames are the attachment's frame sliced
    /// by the precomputed row offsets.
    private mutating func appendTableRowSpecs(for table: TableAttachment, range: NSRange) {
        var offset: CGFloat = 0
        for (index, row) in table.model.rows.enumerated() {
            let height = table.layout.rowHeights[index]
            let content = row.map(\.plainText).joined(separator: ", ")
            let label = labels.table.row
                .replacingOccurrences(of: "{n}", with: String(index + 1))
                .replacingOccurrences(of: "{content}", with: content)
            specs.append(MarkdownAccessibilityElementSpec(
                kind: .tableRow(offset: offset, height: height, isHeader: row.first?.isHeader ?? false),
                label: label,
                range: range,
                headingLevel: nil,
                value: nil
            ))
            offset += height
        }
    }

    private mutating func appendTextSpec(for range: NSRange, requireLetterOrDigit: Bool = false) {
        guard let (visible, label) = visibleText(in: range) else { return }
        if requireLetterOrDigit, label.rangeOfCharacter(from: .alphanumerics) == nil {
            return
        }
        specs.append(contextSpec(kind: .text, label: label, range: visible, requireListStart: true))
    }

    /// A spec with the heading, list, and blockquote context at the start
    /// of `range`. `requireListStart` limits the list announcement to the
    /// item's first segment.
    private func contextSpec(
        kind: MarkdownAccessibilityElementSpec.Kind,
        label: String,
        range: NSRange,
        requireListStart: Bool
    ) -> MarkdownAccessibilityElementSpec {
        let position = range.location
        let parts = [
            listAnnouncement(at: position, requireStart: requireListStart),
            blockquoteAnnouncement(at: position)
        ].compactMap { $0 }
        return MarkdownAccessibilityElementSpec(
            kind: kind,
            label: label,
            range: range,
            headingLevel: MarkdownAttributeValue.intValue(from: attribute(MarkdownAttribute.headingLevel, at: position)),
            value: parts.isEmpty ? nil : parts.joined(separator: ", ")
        )
    }

    /// The trimmed range and its spoken text, with attachment placeholders
    /// removed (an attachment without its own element would otherwise be
    /// read as "object replacement character"); nil when nothing speakable
    /// remains.
    private func visibleText(in range: NSRange) -> (range: NSRange, label: String)? {
        guard let visible = trimmedRange(of: range) else { return nil }
        var label = string.substring(with: visible)
        if string.range(of: Self.attachmentCharacter, options: [], range: visible).location != NSNotFound {
            label = label
                .replacingOccurrences(of: Self.attachmentCharacter, with: "")
                .trimmingCharacters(in: Self.skippable)
        }
        return label.isEmpty ? nil : (visible, label)
    }

    // MARK: - Context

    private func attribute(_ key: NSAttributedString.Key, at position: Int) -> Any? {
        guard position < text.length else { return nil }
        return text.attribute(key, at: position, effectiveRange: nil)
    }

    private func blockquoteAnnouncement(at position: Int) -> String? {
        guard let depth = MarkdownAttributeValue.intValue(
            from: attribute(MarkdownAttribute.blockquoteDepth, at: position)
        ) else { return nil }
        return depth >= 1 ? labels.blockquote.nestedQuote : labels.blockquote.quote
    }

    private func listAnnouncement(at position: Int, requireStart: Bool) -> String? {
        guard let number = MarkdownAttributeValue.intValue(
            from: attribute(MarkdownAttribute.listItemNumber, at: position)
        ) else { return nil }
        let depth = MarkdownAttributeValue.intValue(from: attribute(MarkdownAttribute.listDepth, at: position)) ?? 0
        if requireStart, !isListItemStart(position) {
            return nil
        }

        let level = depth > 0 ? labels.list.nested : labels.list.top
        if let taskValue = attribute(MarkdownAttribute.taskListItem, at: position) {
            return MarkdownAttributeValue.boolValue(from: taskValue) ? level.checkedTask : level.uncheckedTask
        }
        let type = MarkdownAttributeValue.intValue(from: attribute(MarkdownAttribute.listType, at: position))
        if type == ListType.ordered.rawValue {
            return level.orderedItem.replacingOccurrences(of: "{n}", with: String(number))
        }
        return level.bulletPoint
    }

    /// Whether `position` is at (or just after) the first visible character
    /// of its list item. The item's extent is where BOTH number and depth
    /// are constant — number alone merges across nesting levels (outer item
    /// 1 / inner item 1 are adjacent equal values), depth alone merges
    /// siblings.
    private func isListItemStart(_ position: Int) -> Bool {
        let fullRange = NSRange(location: 0, length: text.length)
        var numberRun = NSRange()
        _ = text.attribute(MarkdownAttribute.listItemNumber, at: position, longestEffectiveRange: &numberRun, in: fullRange)
        var depthRun = numberRun
        _ = text.attribute(MarkdownAttribute.listDepth, at: position, longestEffectiveRange: &depthRun, in: fullRange)

        let itemRange = NSIntersectionRange(numberRun, depthRun)
        let firstVisible = trimmedRange(of: itemRange)?.location ?? itemRange.location
        return position <= firstVisible + 1
    }

    // MARK: - Trimming

    private func trimmedRange(of range: NSRange) -> NSRange? {
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

    private func isSkippable(_ character: unichar) -> Bool {
        guard let scalar = Unicode.Scalar(character) else { return false }
        return Self.skippable.contains(scalar)
    }
}
