import UIKit

package protocol ViewTransition: Sendable {
    @MainActor
    func animate(_ view: UIView, completion: @escaping () -> Void)
}

package protocol MarkdownStreamingPlugin: Equatable, Sendable {
    var transition: (any ViewTransition)? { get }

    func makeSession(inputs: MarkdownRenderInputs) -> any MarkdownStreamingSession
}

package struct AnyMarkdownStreamingPlugin: Equatable, Sendable {
    package let base: any MarkdownStreamingPlugin

    package init(_ base: any MarkdownStreamingPlugin) {
        self.base = base
    }

    var transition: (any ViewTransition)? { base.transition }

    func makeSession(inputs: MarkdownRenderInputs) -> any MarkdownStreamingSession {
        base.makeSession(inputs: inputs)
    }

    package static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.base.isEqual(to: rhs.base)
    }
}

package protocol MarkdownStreamingSession: AnyObject {
    var id: UInt64 { get }
    var key: MarkdownRenderInputs { get }

    func render(_ markdown: String, plugin: AnyMarkdownStreamingPlugin) -> StreamingRenderResult
}

package struct StreamingRenderResult {
    package let text: NSAttributedString
    package let source: String
    package let lineage: StreamingLineage

    package init(text: NSAttributedString, source: String, lineage: StreamingLineage) {
        self.text = text
        self.source = source
        self.lineage = lineage
    }
}

package struct StreamingLineage: Equatable {
    package let session: UInt64
    package let stableLength: Int

    package init(session: UInt64, stableLength: Int) {
        self.session = session
        self.stableLength = stableLength
    }
}
