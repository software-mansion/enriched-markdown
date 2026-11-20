import EnrichedMarkdown
import UIKit
import os

final class StreamingRenderSession: MarkdownStreamingSession {
    private struct Update {
        let snapshot: StreamingSnapshot
        let finished: String
        let finishedBlocks: [MarkdownASTNode]
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
    private var splitsBlocks: Bool = true

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
            resetStableBlocks()
        }
        let update = prepare(markdown, options: options)
        let stableBytes = stableSource.utf8.count
        let finishedBytes = stableBytes + update.finished.utf8.count
        let snapshotEnd = stableBytes + update.snapshot.finishedBytes

        let text = NSMutableAttributedString(attributedString: stableOutput)
        let context = renderer.makeRootContext()
        if let boundary {
            context.restore(boundary)
        }
        let stableLength = text.length
        render(update.finishedBlocks, into: text, context: context, byteOffset: stableBytes)
        let finishedEnd = text.length
        let state = context.boundaryState

        let tail = Self.text(of: markdown, in: finishedBytes..<snapshotEnd) + update.snapshot.tail
        if !tail.isEmpty {
            var root = MarkdownRenderer.parse(tail, options: parsingOptions)
            if update.snapshot.endsInsideOpenCodeFence,
               let marked = Self.markingPendingCodeBlock(root, tailEnd: Self.trimmingTrailingWhitespace(tail)).marked {
                root = marked
            }
            render(root.children, into: text, context: context, byteOffset: finishedBytes)
        }
        renderer.finishBlocks(in: text, range: NSRange(location: stableLength, length: text.length - stableLength), context: context)

        if !update.finished.isEmpty, Self.hasVisibleContent(text, in: NSRange(location: finishedEnd, length: text.length - finishedEnd)) {
            stableOutput.append(text.attributedSubstring(from: NSRange(location: stableLength, length: finishedEnd - stableLength)))
            InlineBackground.carryBorderRoom(from: text, to: stableOutput)
            stableSource += update.finished
            boundary = state
        }
        TrailingSpacing.strip(from: text, codeBlockPadding: key.config.codeBlock.padding ?? 0)
        return StreamingRenderResult(
            text: text,
            source: Self.text(of: markdown, in: 0..<snapshotEnd) + update.snapshot.tail,
            lineage: StreamingLineage(session: id, stableLength: unchangedLength(of: text))
        )
    }

    private func prepare(_ markdown: String, options: MarkdownStreamingOptions) -> Update {
        let stableBytes = stableSource.utf8.count
        let snapshot = StreamingSnapshot(of: markdown, from: stableBytes, parsing: parsingOptions, streaming: options)
        if splitsBlocks, !parsingOptions.preserveBlankLines, !snapshot.mayDefineLinkReference {
            let finished = Self.text(of: markdown, in: stableBytes..<stableBytes + snapshot.finishedBytes)
            if let blocks = finishedBlocks(of: finished) {
                return Update(snapshot: snapshot, finished: finished, finishedBlocks: blocks)
            }
            splitsBlocks = false
        }
        guard stableBytes > 0 else { return Update(snapshot: snapshot, finished: "", finishedBlocks: []) }
        resetStableBlocks()
        let whole = StreamingSnapshot(of: markdown, from: 0, parsing: parsingOptions, streaming: options)
        return Update(snapshot: whole, finished: "", finishedBlocks: [])
    }

    private func finishedBlocks(of markdown: String) -> [MarkdownASTNode]? {
        guard !markdown.isEmpty else { return [] }
        let root = MarkdownRenderer.parse(markdown + Self.probe + "\n", options: parsingOptions)
        guard let last = root.children.last, last.type == .paragraph, last.children.count == 1,
              last.children[0].type == .text, last.children[0].content == Self.probe
        else { return nil }
        return Array(root.children.dropLast())
    }

    private func render(_ blocks: [MarkdownASTNode], into text: NSMutableAttributedString, context: RenderContext, byteOffset: Int) {
        let start = text.length
        renderer.renderBlocks(blocks, into: text, context: context)
        if byteOffset > 0 {
            Self.shiftSourceRanges(in: text, range: NSRange(location: start, length: text.length - start), by: byteOffset)
        }
    }

    private func resetStableBlocks() {
        stableSource = ""
        stableOutput.setAttributedString(NSAttributedString())
        boundary = nil
    }

    private func unchangedLength(of text: NSMutableAttributedString) -> Int {
        guard text.length <= stableOutput.length else { return stableOutput.length }
        guard text.length > 0 else { return 0 }
        return text.mutableString.paragraphRange(for: NSRange(location: text.length - 1, length: 0)).location
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
            return (true, MarkdownASTNode(type: node.type, content: node.content, attributes: node.attributes, children: children))
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
        output.enumerateAttribute(MarkdownAttribute.sourceRange, in: range) { value, runRange, _ in
            guard let sourceRange = (value as? NSValue)?.rangeValue else { return }
            let shifted = NSRange(location: sourceRange.location + offset, length: sourceRange.length)
            output.addAttribute(MarkdownAttribute.sourceRange, value: NSValue(range: shifted), range: runRange)
        }
    }
}
