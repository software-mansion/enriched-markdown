import EnrichedMarkdown
import UIKit
import os

final class StreamingRenderSession: MarkdownStreamingSession {
    private struct Part {
        var blocks: [MarkdownASTNode] = []
        var sourceOffset: Int = 0
    }

    private struct Item {
        let source: String
        let node: MarkdownASTNode
    }

    private struct Update {
        let source: String
        var finished: String = ""
        var finishedPart = Part()
        var tailPart = Part()
        var openItem: Item?
    }

    private struct ListAnchor {
        let sourceBytes: Int
        let outputLength: Int
        let boundary: RenderContext.BoundaryState?
        let openItem: Item?
    }

    private static let nextID = OSAllocatedUnfairLock<UInt64>(initialState: 0)
    private static let probe: String = "x"

    let key: MarkdownRenderInputs
    private(set) var id: UInt64
    private let parsingOptions: MarkdownParsingOptions
    private lazy var renderer = AttributedRenderer(inputs: key)

    private var stableSource: String = ""
    private let stableOutput = NSMutableAttributedString()
    private var boundary: RenderContext.BoundaryState?
    private var openItem: Item?
    private var listAnchor: ListAnchor?
    private var splitsBlocks: Bool = true
    private var splitsItems: Bool = true
    private var unsplitItemsEnd: Int?

    init(inputs: MarkdownRenderInputs) {
        key = inputs.sessionKey
        id = Self.makeID()
        parsingOptions = MarkdownRenderer.effectiveParsingOptions(inputs.options, plugins: inputs.plugins.values)
    }

    func render(_ markdown: String, plugin: AnyMarkdownStreamingPlugin) -> StreamingRenderResult {
        render(markdown, options: (plugin.base as? StreamingPlugin)?.options ?? MarkdownStreamingOptions())
    }

    func render(_ markdown: String, options: MarkdownStreamingOptions) -> StreamingRenderResult {
        var markdown = markdown
        markdown.makeContiguousUTF8()
        if !Self.hasPrefix(markdown, stableSource) {
            id = Self.makeID()
            splitsBlocks = true
            splitsItems = true
            resetStableBlocks()
        }
        return render(markdown, options: options, splittingItems: true)
    }

    private func render(_ markdown: String, options: MarkdownStreamingOptions, splittingItems: Bool) -> StreamingRenderResult {
        let update = prepare(markdown, options: options, splittingItems: splittingItems)
        let continuesList = update.openItem != nil
        let text = NSMutableAttributedString(attributedString: stableOutput)
        let context = renderer.makeRootContext()
        if let boundary {
            context.restore(boundary)
        }
        if openItem != nil {
            context.continueOpenList()
        }
        let stableLength = text.length
        render(update.finishedPart, into: text, context: context, continuedByNext: continuesList)
        let finishedEnd = text.length
        let state = context.boundaryState
        if continuesList {
            context.continueOpenList()
        }
        render(update.tailPart, into: text, context: context)
        let leavesListOpen = continuesList && update.tailPart.blocks.first.map(Self.isList) != true
        if context.listRestartRequested || leavesListOpen, splittingItems {
            if context.listRestartRequested {
                unsplitItemsEnd = stableSource.utf8.count + update.finished.utf8.count
            }
            if let listAnchor {
                restore(listAnchor)
            }
            return render(markdown, options: options, splittingItems: false)
        }
        renderer.finishBlocks(in: text, range: NSRange(location: stableLength, length: text.length - stableLength), context: context)

        if !update.finished.isEmpty, Self.hasVisibleContent(text, in: NSRange(location: finishedEnd, length: text.length - finishedEnd)) {
            if update.openItem == nil {
                listAnchor = nil
            } else if listAnchor == nil || update.finishedPart.blocks.count != 1 {
                listAnchor = ListAnchor(sourceBytes: stableSource.utf8.count, outputLength: stableLength, boundary: boundary, openItem: openItem)
            }
            stableOutput.append(text.attributedSubstring(from: NSRange(location: stableLength, length: finishedEnd - stableLength)))
            InlineBackground.carryBorderRoom(from: text, to: stableOutput)
            stableSource += update.finished
            boundary = state
            openItem = update.openItem
        }
        TrailingSpacing.strip(from: text, codeBlockPadding: key.config.codeBlock.padding ?? 0)
        return StreamingRenderResult(
            text: text,
            source: update.source,
            lineage: StreamingLineage(session: id, stableLength: unchangedLength(of: text))
        )
    }

    private func prepare(_ markdown: String, options: MarkdownStreamingOptions, splittingItems: Bool) -> Update {
        let stableBytes = stableSource.utf8.count
        let snapshot = StreamingSnapshot(of: markdown, from: stableBytes, parsing: parsingOptions, streaming: options)
        let blocksEnd = stableBytes + snapshot.finishedBytes
        let source = Self.text(of: markdown, in: 0..<blocksEnd) + snapshot.tail
        if splitsBlocks, !parsingOptions.preserveBlankLines, !snapshot.mayDefineLinkReference {
            let itemsEnd = stableBytes + snapshot.finishedItemsBytes
            let rest = snapshot.tail.utf8.dropFirst(itemsEnd - blocksEnd)
            if splittingItems, splitsItems, itemsEnd > blocksEnd, itemsEnd != unsplitItemsEnd, !rest.allSatisfy(Self.isWhitespace) {
                let lastItem = Self.text(of: markdown, in: stableBytes + snapshot.lastItemBytes..<itemsEnd)
                if let update = split(markdown, at: itemsEnd, lastItem: lastItem, snapshot: snapshot, source: source) {
                    return update
                }
                splitsItems = false
            }
            if let update = split(markdown, at: blocksEnd, lastItem: nil, snapshot: snapshot, source: source) {
                return update
            }
            splitsBlocks = false
        }
        guard stableBytes > 0 else {
            return Update(source: source, tailPart: Part(blocks: tailBlocks(of: source, snapshot: snapshot)))
        }
        resetStableBlocks()
        return prepare(markdown, options: options, splittingItems: splittingItems)
    }

    private func split(
        _ markdown: String,
        at end: Int,
        lastItem: String?,
        snapshot: StreamingSnapshot,
        source: String
    ) -> Update? {
        let stableBytes = stableSource.utf8.count
        var update = Update(source: source, finished: Self.text(of: markdown, in: stableBytes..<end))
        if update.finished.isEmpty {
            update.openItem = openItem
        } else {
            let context = openItem?.source ?? ""
            let probe = lastItem == nil ? Self.probe : Self.marker(of: markdown, at: end) + " " + Self.probe
            var blocks = MarkdownRenderer.parse(context + update.finished + probe + "\n", options: parsingOptions).children
            guard lastItem == nil ? Self.droppingProbeParagraph(&blocks) : Self.droppingProbeItem(&blocks),
                  Self.droppingFirstItem(&blocks, matching: openItem)
            else { return nil }
            if let lastItem {
                guard let node = blocks.last?.children.last, !node.children.isEmpty else { return nil }
                update.openItem = Item(source: lastItem, node: node)
            }
            update.finishedPart = Part(blocks: blocks, sourceOffset: stableBytes - context.utf8.count)
        }
        let context = update.openItem?.source ?? ""
        var blocks = tailBlocks(of: context + Self.text(of: source, in: end..<source.utf8.count), snapshot: snapshot)
        guard Self.droppingFirstItem(&blocks, matching: update.openItem) else { return nil }
        update.tailPart = Part(blocks: blocks, sourceOffset: end - context.utf8.count)
        return update
    }

    private func tailBlocks(of markdown: String, snapshot: StreamingSnapshot) -> [MarkdownASTNode] {
        guard !markdown.isEmpty else { return [] }
        let root = MarkdownRenderer.parse(markdown, options: parsingOptions)
        guard snapshot.endsInsideOpenCodeFence,
              let marked = Self.markingPendingCodeBlock(root, tailEnd: Self.trimmingTrailingWhitespace(markdown)).marked
        else { return root.children }
        return marked.children
    }

    private func render(_ part: Part, into text: NSMutableAttributedString, context: RenderContext, continuedByNext: Bool = false) {
        let start = text.length
        if continuedByNext, let last = part.blocks.last {
            renderer.renderBlocks(Array(part.blocks.dropLast()), into: text, context: context)
            context.listContinuedByNext = true
            renderer.renderBlocks([last], into: text, context: context)
            context.listContinuedByNext = false
        } else {
            renderer.renderBlocks(part.blocks, into: text, context: context)
        }
        if part.sourceOffset > 0 {
            Self.shiftSourceRanges(in: text, range: NSRange(location: start, length: text.length - start), by: part.sourceOffset)
        }
    }

    private func resetStableBlocks() {
        stableSource = ""
        stableOutput.setAttributedString(NSAttributedString())
        boundary = nil
        openItem = nil
        listAnchor = nil
        unsplitItemsEnd = nil
    }

    private func restore(_ anchor: ListAnchor) {
        stableSource = Self.text(of: stableSource, in: 0..<anchor.sourceBytes)
        stableOutput.deleteCharacters(in: NSRange(location: anchor.outputLength, length: stableOutput.length - anchor.outputLength))
        boundary = anchor.boundary
        openItem = anchor.openItem
        listAnchor = nil
    }

    private func unchangedLength(of text: NSMutableAttributedString) -> Int {
        guard text.length <= stableOutput.length else { return stableOutput.length }
        guard text.length > 0 else { return 0 }
        return text.mutableString.paragraphRange(for: NSRange(location: text.length - 1, length: 0)).location
    }

    private static func droppingProbeParagraph(_ blocks: inout [MarkdownASTNode]) -> Bool {
        guard let last = blocks.last, isProbe(last) else { return false }
        blocks.removeLast()
        return true
    }

    private static func droppingProbeItem(_ blocks: inout [MarkdownASTNode]) -> Bool {
        guard let list = blocks.last, isList(list), list.children.count >= 2, let item = list.children.last,
              item.children.count == 1, isProbe(item.children[0])
        else { return false }
        blocks[blocks.count - 1] = replacingChildren(of: list, with: Array(list.children.dropLast()))
        return true
    }

    private static func droppingFirstItem(_ blocks: inout [MarkdownASTNode], matching item: Item?) -> Bool {
        guard let item else { return true }
        guard let list = blocks.first, isList(list), let first = list.children.first, matches(first, item.node) else { return false }
        if list.children.count == 1 {
            blocks.removeFirst()
        } else {
            blocks[0] = replacingChildren(of: list, with: Array(list.children.dropFirst()))
        }
        return true
    }

    private static func matches(_ lhs: MarkdownASTNode, _ rhs: MarkdownASTNode) -> Bool {
        lhs.type == rhs.type && lhs.content == rhs.content && lhs.children.count == rhs.children.count
            && zip(lhs.children, rhs.children).allSatisfy(matches)
    }

    private static func isProbe(_ node: MarkdownASTNode) -> Bool {
        node.type == .paragraph && node.children.count == 1 && node.children[0].type == .text && node.children[0].content == probe
    }

    private static func isList(_ node: MarkdownASTNode) -> Bool {
        node.type == .orderedList || node.type == .unorderedList
    }

    private static func replacingChildren(of node: MarkdownASTNode, with children: [MarkdownASTNode]) -> MarkdownASTNode {
        MarkdownASTNode(type: node.type, content: node.content, attributes: node.attributes, children: children)
    }

    private static func marker(of markdown: String, at offset: Int) -> String {
        String(markdown.utf8.dropFirst(offset).prefix { !isWhitespace($0) }) ?? ""
    }

    private static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || byte == UInt8(ascii: "\t") || byte == UInt8(ascii: "\n") || byte == UInt8(ascii: "\r")
    }

    private static func markingPendingCodeBlock(_ node: MarkdownASTNode, tailEnd: String) -> (found: Bool, marked: MarkdownASTNode?) {
        if node.type == .codeBlock {
            guard tailEnd.hasSuffix(trimmingTrailingWhitespace(node.flattenedText())) else { return (true, nil) }
            var attributes = node.attributes
            attributes["pending"] = "true"
            return (true, MarkdownASTNode(type: node.type, content: node.content, attributes: attributes, children: node.children))
        }
        var children = node.children
        for index in children.indices.reversed() {
            let result = markingPendingCodeBlock(children[index], tailEnd: tailEnd)
            guard result.found else { continue }
            guard let marked = result.marked else { return (true, nil) }
            children[index] = marked
            return (true, replacingChildren(of: node, with: children))
        }
        return (false, nil)
    }

    private static func makeID() -> UInt64 {
        nextID.withLock { id in
            id += 1
            return id
        }
    }

    private static func hasPrefix(_ markdown: String, _ prefix: String) -> Bool {
        guard !prefix.isEmpty else { return true }
        guard markdown.utf8.count >= prefix.utf8.count else { return false }
        let compared = markdown.utf8.withContiguousStorageIfAvailable { markdownBytes in
            prefix.utf8.withContiguousStorageIfAvailable { prefixBytes in
                memcmp(markdownBytes.baseAddress, prefixBytes.baseAddress, prefixBytes.count) == 0
            }
        }
        return compared.flatMap { $0 } ?? markdown.utf8.starts(with: prefix.utf8)
    }

    private static func text(of markdown: String, in range: Range<Int>) -> String {
        guard !range.isEmpty else { return "" }
        let slice = markdown.utf8.withContiguousStorageIfAvailable { String(bytes: UnsafeBufferPointer(rebasing: $0[range]), encoding: .utf8) }
        return (slice ?? String(bytes: Array(markdown.utf8)[range], encoding: .utf8)) ?? ""
    }

    private static func trimmingTrailingWhitespace(_ text: String) -> String {
        var trimmed = text
        while let last = trimmed.last, last.isWhitespace {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func hasVisibleContent(_ text: NSMutableAttributedString, in range: NSRange) -> Bool {
        text.mutableString.rangeOfCharacter(from: ParagraphStyleHelpers.nonNewlines, options: [], range: range).location != NSNotFound
    }

    private static func shiftSourceRanges(in output: NSMutableAttributedString, range: NSRange, by offset: Int) {
        var runs: [(range: NSRange, source: NSRange)] = []
        output.enumerateAttribute(MarkdownAttribute.sourceRange, in: range) { value, runRange, _ in
            guard let sourceRange = (value as? NSValue)?.rangeValue else { return }
            runs.append((runRange, NSRange(location: sourceRange.location + offset, length: sourceRange.length)))
        }
        for run in runs {
            output.addAttribute(MarkdownAttribute.sourceRange, value: NSValue(range: run.source), range: run.range)
        }
    }
}
