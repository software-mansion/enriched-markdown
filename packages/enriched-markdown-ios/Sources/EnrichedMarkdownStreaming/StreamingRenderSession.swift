import EnrichedMarkdown
import UIKit

final class StreamingRenderSession: MarkdownStreamingSession {
    private struct Snapshot {
        let bytes: Int
        let outputLength: Int
        let boundary: RenderContext.BoundaryState?
    }

    private struct Rendered {
        let text: NSMutableAttributedString
        let finishedEnd: Int
        let state: RenderContext.BoundaryState
        let restartRequested: Bool
    }

    let key: MarkdownRenderInputs
    private(set) var id: UInt64 = 0
    private let parsingOptions: MarkdownParsingOptions
    private lazy var renderer = AttributedRenderer(inputs: key)
    private let core: StreamingCoreSession

    private let stableOutput = NSMutableAttributedString()
    private var boundary: RenderContext.BoundaryState?
    private var snapshots: [Snapshot] = [Snapshot(bytes: 0, outputLength: 0, boundary: nil)]

    init(inputs: MarkdownRenderInputs) {
        key = inputs.sessionKey
        parsingOptions = MarkdownRenderer.effectiveParsingOptions(inputs.options, plugins: inputs.plugins.values)
        core = StreamingCoreSession(options: parsingOptions)
    }

    func render(_ markdown: String, plugin: AnyMarkdownStreamingPlugin) -> StreamingRenderResult {
        render(markdown, options: (plugin.base as? StreamingPlugin)?.options ?? MarkdownStreamingOptions())
    }

    func render(_ markdown: String, options: MarkdownStreamingOptions) -> StreamingRenderResult {
        var update = core.update(markdown, options: options)
        var rendered = render(markdown, update: update)
        if rendered.restartRequested {
            update = core.update(markdown, options: options, restartingOpenList: true)
            rendered = render(markdown, update: update)
        }
        commit(update, rendered)
        TrailingSpacing.strip(from: rendered.text, codeBlockPadding: key.config.codeBlock.padding ?? 0)
        let finishedEnd = update.frozenBytes + update.finishedBytes
        let source = (String(bytes: markdown.utf8.prefix(finishedEnd), encoding: .utf8) ?? "") + update.tail
        return StreamingRenderResult(
            text: rendered.text,
            source: source,
            lineage: StreamingLineage(session: id, stableLength: unchangedLength(of: rendered.text))
        )
    }

    private func unchangedLength(of text: NSMutableAttributedString) -> Int {
        guard text.length <= stableOutput.length else { return stableOutput.length }
        guard text.length > 0 else { return 0 }
        return text.mutableString.paragraphRange(for: NSRange(location: text.length - 1, length: 0)).location
    }

    private func render(_ markdown: String, update: StreamingCoreSession.Update) -> Rendered {
        synchronize(with: update)
        let text = NSMutableAttributedString(attributedString: stableOutput)
        let context = renderer.makeRootContext()
        if let boundary {
            context.restore(boundary)
        }
        if update.finishedContinuesList {
            context.listContinuation = boundary?.openList
        }
        let stableLength = text.length
        let finished = String(bytes: markdown.utf8.dropFirst(update.frozenBytes).prefix(update.finishedBytes), encoding: .utf8) ?? ""
        render(finished, into: text, context: context, byteOffset: update.frozenBytes, continuedByNext: update.finishedContinuedByTail)
        let finishedEnd = text.length
        let state = context.boundaryState
        if update.tailContinuesList {
            context.listContinuation = state.openList
        }
        render(
            update.tail,
            root: codeBlockTail(of: update),
            into: text,
            context: context,
            byteOffset: update.frozenBytes + update.finishedBytes,
            pendingCodeBlock: update.tailEndsInsideOpenCodeFence
        )
        renderer.finishBlocks(in: text, range: NSRange(location: stableLength, length: text.length - stableLength), context: context)
        return Rendered(text: text, finishedEnd: finishedEnd, state: state, restartRequested: context.listRestartRequested)
    }

    private func synchronize(with update: StreamingCoreSession.Update) {
        if update.lineage != id {
            id = update.lineage
            stableOutput.setAttributedString(NSAttributedString())
            boundary = nil
            snapshots = [Snapshot(bytes: 0, outputLength: 0, boundary: nil)]
        }
        guard let index = snapshots.firstIndex(where: { $0.bytes == update.frozenBytes }), index + 1 < snapshots.count else { return }
        let snapshot = snapshots[index]
        stableOutput.deleteCharacters(in: NSRange(location: snapshot.outputLength, length: stableOutput.length - snapshot.outputLength))
        boundary = snapshot.boundary
        snapshots.removeSubrange((index + 1)...)
    }

    private func commit(_ update: StreamingCoreSession.Update, _ rendered: Rendered) {
        guard update.finishedBytes > 0 else { return }
        let stableLength = stableOutput.length
        stableOutput.append(rendered.text.attributedSubstring(from: NSRange(location: stableLength, length: rendered.finishedEnd - stableLength)))
        boundary = rendered.state
        let snapshot = Snapshot(bytes: update.frozenBytes + update.finishedBytes, outputLength: stableOutput.length, boundary: boundary)
        if update.finishedContinuedByTail {
            snapshots.append(snapshot)
        } else {
            snapshots = [snapshot]
        }
    }

    private func codeBlockTail(of update: StreamingCoreSession.Update) -> MarkdownASTNode? {
        guard let bodyStart = update.tailCodeBodyStart else { return nil }
        let bytes = Array(update.tail.utf8)
        guard bodyStart <= bytes.count,
              let head = String(bytes: bytes[..<bodyStart], encoding: .utf8),
              let body = String(bytes: bytes[bodyStart...], encoding: .utf8)
        else { return nil }
        let root = MarkdownRenderer.parse(head, options: parsingOptions)
        guard let opened = root.children.last, opened.type == .codeBlock else { return nil }
        var attributes = opened.attributes
        attributes["pending"] = "true"
        let range = [
            SourceOffsetAnnotator.sourceStartKey: String(bodyStart),
            SourceOffsetAnnotator.sourceEndKey: String(bytes.count)
        ]
        let code = MarkdownASTNode(type: .text, content: body, attributes: range)
        let block = MarkdownASTNode(type: .codeBlock, attributes: attributes.merging(range) { _, new in new }, children: [code])
        let children = Array(root.children.dropLast()) + [block]
        return MarkdownASTNode(type: root.type, content: root.content, attributes: root.attributes, children: children)
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

    private static func trimmingTrailingWhitespace(_ text: String) -> String {
        var trimmed = text
        while let last = trimmed.last, last.isWhitespace {
            trimmed.removeLast()
        }
        return trimmed
    }

    private static func shiftSourceRanges(in output: NSMutableAttributedString, range: NSRange, by offset: Int) {
        output.enumerateAttribute(MarkdownAttribute.sourceRange, in: range) { value, runRange, _ in
            guard let sourceRange = (value as? NSValue)?.rangeValue else { return }
            let shifted = NSRange(location: sourceRange.location + offset, length: sourceRange.length)
            output.addAttribute(MarkdownAttribute.sourceRange, value: NSValue(range: shifted), range: runRange)
        }
    }
}
