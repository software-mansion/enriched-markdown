import EnrichedMarkdown
import UIKit
import os

final class StreamingRenderSession: MarkdownStreamingSession {
    private static let nextID = OSAllocatedUnfairLock<UInt64>(initialState: 0)

    let key: MarkdownRenderInputs
    private(set) var id: UInt64
    private let parsingOptions: MarkdownParsingOptions
    private lazy var renderer = AttributedRenderer(inputs: key)

    private var stableSource = ""
    private let stableOutput = NSMutableAttributedString()
    private var boundary: RenderContext.BoundaryState?
    private var rendersWhole: Bool

    init(inputs: MarkdownRenderInputs) {
        key = inputs.sessionKey
        id = Self.makeID()
        parsingOptions = MarkdownRenderer.effectiveParsingOptions(inputs.options, plugins: inputs.plugins.values)
        rendersWhole = parsingOptions.preserveBlankLines
    }

    func render(_ markdown: String, plugin: AnyMarkdownStreamingPlugin) -> StreamingRenderResult {
        render(markdown, options: (plugin.base as? StreamingPlugin)?.options ?? MarkdownStreamingOptions())
    }

    func render(_ markdown: String, options: MarkdownStreamingOptions) -> StreamingRenderResult {
        if !Self.hasPrefix(markdown, stableSource) {
            resetStableBlocks()
        }
        var bytes = Array(markdown.utf8.dropFirst(stableSource.utf8.count))
        var scan = StreamingBlockSplitter.scan(bytes)
        if scan.hasLinkReferenceDefinition, !rendersWhole {
            rendersWhole = true
            resetStableBlocks()
            bytes = Array(markdown.utf8)
            scan = StreamingBlockSplitter.scan(bytes)
        }
        let cut = rendersWhole ? 0 : (scan.lastCut ?? 0)
        let finished = String(bytes: bytes[..<cut], encoding: .utf8) ?? ""
        let tail = renderable(
            String(bytes: bytes[cut...], encoding: .utf8) ?? "",
            openFenceStart: scan.openFenceStart.map { $0 - cut },
            options: options
        )
        let source = stableSource + finished + tail

        let text = NSMutableAttributedString(attributedString: stableOutput)
        let context = renderer.makeRootContext()
        if let boundary {
            context.restore(boundary)
        }
        let stableLength = text.length
        render(finished, into: text, context: context, byteOffset: stableSource.utf8.count)
        let finishedEnd = text.length
        let state = context.boundaryState
        render(
            tail,
            into: text,
            context: context,
            byteOffset: stableSource.utf8.count + finished.utf8.count,
            markingPendingCodeBlock: options.codeBlocks == .progressive && scan.openFenceStart != nil
        )
        renderer.finishBlocks(in: text, range: NSRange(location: stableLength, length: text.length - stableLength), context: context)

        if !finished.isEmpty, Self.hasVisibleContent(text, in: NSRange(location: finishedEnd, length: text.length - finishedEnd)) {
            stableOutput.append(text.attributedSubstring(from: NSRange(location: stableLength, length: finishedEnd - stableLength)))
            boundary = state
            stableSource += finished
        }
        TrailingSpacing.strip(from: text, codeBlockPadding: key.config.codeBlock.padding ?? 0)
        return StreamingRenderResult(text: text, source: source, lineage: StreamingLineage(session: id, stableLength: stableOutput.length))
    }

    private func renderable(_ tail: String, openFenceStart: Int?, options: MarkdownStreamingOptions) -> String {
        let filtered = StreamingMarkdownFilter.renderable(
            tail,
            openFenceStart: openFenceStart,
            options: options,
            latexMath: parsingOptions.latexMathEnabled
        )
        return StreamingMarkdownRepair.repair(filtered, options: parsingOptions)
    }

    private func render(
        _ markdown: String,
        into text: NSMutableAttributedString,
        context: RenderContext,
        byteOffset: Int,
        markingPendingCodeBlock: Bool = false
    ) {
        guard !markdown.isEmpty else { return }
        var root = MarkdownRenderer.parse(markdown, options: parsingOptions)
        if markingPendingCodeBlock,
           let marked = Self.markingPendingCodeBlock(root, tailEnd: Self.trimmingTrailingWhitespace(markdown)).marked {
            root = marked
        }
        let start = text.length
        renderer.renderBlocks(root.children, into: text, context: context)
        if byteOffset > 0 {
            Self.shiftSourceRanges(in: text, range: NSRange(location: start, length: text.length - start), by: byteOffset)
        }
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

    private func resetStableBlocks() {
        id = Self.makeID()
        stableSource = ""
        stableOutput.setAttributedString(NSAttributedString())
        boundary = nil
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
