import EnrichedMarkdown
import UIKit
import os

final class StreamingRenderSession: MarkdownStreamingSession {
    private static let nextID = OSAllocatedUnfairLock<UInt64>(initialState: 0)

    private struct Tail {
        let markdown: String
        let root: MarkdownASTNode?
    }

    private struct ListAnchor {
        let sourceCount: Int
        let outputLength: Int
        let boundary: RenderContext.BoundaryState?
    }

    let key: MarkdownRenderInputs
    private(set) var id: UInt64
    private let parsingOptions: MarkdownParsingOptions
    private lazy var renderer = AttributedRenderer(inputs: key)

    private var stableSource = ""
    private let stableOutput = NSMutableAttributedString()
    private var boundary: RenderContext.BoundaryState?
    private var continuesList = false
    private var listAnchor: ListAnchor?
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
        return render(markdown, options: options, cuttingLists: true)
    }

    private func render(_ markdown: String, options: MarkdownStreamingOptions, cuttingLists: Bool) -> StreamingRenderResult {
        var bytes = Array(markdown.utf8.dropFirst(stableSource.utf8.count))
        var scan = StreamingBlockSplitter.scan(bytes)
        if scan.hasLinkReferenceDefinition, !rendersWhole {
            rendersWhole = true
            resetStableBlocks()
            bytes = Array(markdown.utf8)
            scan = StreamingBlockSplitter.scan(bytes)
        }
        let cut = rendersWhole ? nil : cuttingLists ? scan.lastCut : scan.lastBlockCut
        let cutOffset = cut?.offset ?? 0
        let finished = String(bytes: bytes[..<cutOffset], encoding: .utf8) ?? ""
        let unfinished = String(bytes: bytes[cutOffset...], encoding: .utf8) ?? ""
        let filtered = StreamingMarkdownFilter.renderable(unfinished, options: options)
        let tail = parseTail(filtered)
        let source = stableSource + finished + tail.markdown

        let text = NSMutableAttributedString(attributedString: stableOutput)
        let context = renderer.makeRootContext()
        if let boundary {
            context.restore(boundary)
        }
        if continuesList {
            context.listContinuation = boundary?.openList
        }
        let stableLength = text.length
        let finishedOffset = stableSource.utf8.count
        render(finished, into: text, context: context, byteOffset: finishedOffset, continuedByNext: cut?.continuesList ?? false)
        let finishedEnd = text.length
        let state = context.boundaryState
        if cut?.continuesList == true {
            context.listContinuation = state.openList
        }
        render(
            tail.markdown,
            root: tail.root,
            into: text,
            context: context,
            byteOffset: finishedOffset + finished.utf8.count,
            pendingCodeBlock: filtered.endsInsideOpenCodeFence
        )
        renderer.finishBlocks(in: text, range: NSRange(location: stableLength, length: text.length - stableLength), context: context)

        if cuttingLists, context.listRestartRequested {
            if let listAnchor {
                rollBack(to: listAnchor)
            }
            return render(markdown, options: options, cuttingLists: false)
        }

        let tailIsVisible = Self.hasVisibleContent(text, in: NSRange(location: finishedEnd, length: text.length - finishedEnd))
        if !tailIsVisible, cut?.continuesList ?? continuesList {
            renderer.closeContinuedList(in: text, context: context)
        }
        if !finished.isEmpty, tailIsVisible {
            commit(
                finished,
                output: text.attributedSubstring(from: NSRange(location: stableLength, length: finishedEnd - stableLength)),
                boundary: state,
                continuesList: cut?.continuesList ?? false
            )
        }
        TrailingSpacing.strip(from: text, codeBlockPadding: key.config.codeBlock.padding ?? 0)
        return StreamingRenderResult(text: text, source: source, lineage: StreamingLineage(session: id, stableLength: stableOutput.length))
    }

    private func commit(
        _ finished: String,
        output: NSAttributedString,
        boundary state: RenderContext.BoundaryState,
        continuesList cutContinuesList: Bool
    ) {
        if !cutContinuesList {
            listAnchor = nil
        } else if listAnchor == nil {
            listAnchor = ListAnchor(sourceCount: stableSource.utf8.count, outputLength: stableOutput.length, boundary: boundary)
        }
        continuesList = cutContinuesList
        stableOutput.append(output)
        boundary = state
        stableSource += finished
    }

    private func rollBack(to anchor: ListAnchor) {
        stableSource = String(bytes: stableSource.utf8.prefix(anchor.sourceCount), encoding: .utf8) ?? ""
        stableOutput.deleteCharacters(in: NSRange(location: anchor.outputLength, length: stableOutput.length - anchor.outputLength))
        boundary = anchor.boundary
        continuesList = false
        listAnchor = nil
    }

    private func parseTail(_ filtered: StreamingMarkdownFilter.Result) -> Tail {
        if filtered.endsInsideOpenCodeFence, let tail = openFenceTail(filtered.markdown) {
            return tail
        }
        return Tail(markdown: StreamingMarkdownRepair.repair(filtered.markdown, options: parsingOptions), root: nil)
    }

    private func openFenceTail(_ markdown: String) -> Tail? {
        let bytes = Array(markdown.utf8)
        guard let fence = StreamingBlockSplitter.scan(bytes).openFence,
              let openerEnd = bytes[fence.start...].firstIndex(of: UInt8(ascii: "\n"))
        else { return nil }
        let bodyStart = openerEnd + 1
        guard let head = String(bytes: bytes[..<bodyStart], encoding: .utf8),
              let body = String(bytes: Self.droppingPartialCloser(bytes[bodyStart...], of: fence), encoding: .utf8)
        else { return nil }
        let root = MarkdownRenderer.parse(head, options: parsingOptions)
        guard let opened = root.children.last, opened.type == .codeBlock else { return nil }
        var attributes = opened.attributes
        attributes["pending"] = "true"
        let range = [
            SourceOffsetAnnotator.sourceStartKey: String(bodyStart),
            SourceOffsetAnnotator.sourceEndKey: String(bodyStart + body.utf8.count)
        ]
        let code = MarkdownASTNode(type: .text, content: body, attributes: range)
        let block = MarkdownASTNode(type: .codeBlock, attributes: attributes.merging(range) { _, new in new }, children: [code])
        let children = Array(root.children.dropLast()) + [block]
        return Tail(
            markdown: head + body,
            root: MarkdownASTNode(type: root.type, content: root.content, attributes: root.attributes, children: children)
        )
    }

    private static func droppingPartialCloser(_ body: ArraySlice<UInt8>, of fence: StreamingBlockSplitter.OpenFence) -> ArraySlice<UInt8> {
        let lineStart = body.lastIndex(of: UInt8(ascii: "\n")).map { $0 + 1 } ?? body.startIndex
        let isSpace: (UInt8) -> Bool = { $0 == UInt8(ascii: " ") || $0 == UInt8(ascii: "\t") || $0 == UInt8(ascii: "\r") }
        let line = body[lineStart...].drop(while: isSpace).reversed().drop(while: isSpace)
        guard !line.isEmpty, line.count < fence.length, line.allSatisfy({ $0 == fence.character }) else { return body }
        return body[..<lineStart]
    }

    private func render(
        _ markdown: String,
        root parsed: MarkdownASTNode? = nil,
        into text: NSMutableAttributedString,
        context: RenderContext,
        byteOffset: Int,
        continuedByNext: Bool = false,
        pendingCodeBlock: Bool = false
    ) {
        guard !markdown.isEmpty else { return }
        var root = parsed ?? MarkdownRenderer.parse(markdown, options: parsingOptions)
        if parsed == nil, pendingCodeBlock,
           let marked = Self.markingPendingCodeBlock(root, tailEnd: Self.trimmingTrailingWhitespace(markdown)).marked {
            root = marked
        }
        let start = text.length
        if continuedByNext, let last = root.children.last {
            renderer.renderBlocks(Array(root.children.dropLast()), into: text, context: context)
            context.listContinuedByNext = true
            renderer.renderBlocks([last], into: text, context: context)
            context.listContinuedByNext = false
        } else {
            renderer.renderBlocks(root.children, into: text, context: context)
        }
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
        continuesList = false
        listAnchor = nil
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
