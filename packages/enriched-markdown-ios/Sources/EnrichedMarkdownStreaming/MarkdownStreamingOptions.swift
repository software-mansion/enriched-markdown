import EnrichedMarkdown
import SwiftUI

public struct MarkdownStreamingOptions: Equatable, Sendable {
    public enum TableMode: Equatable, Sendable {
        case progressive
        case hidden
    }

    public enum CodeBlockMode: Equatable, Sendable {
        case progressive
        case hidden
    }

    public var tables: TableMode
    public var codeBlocks: CodeBlockMode
    public var transition: any MarkdownStreamingTransition

    public init(
        tables: TableMode = .progressive,
        codeBlocks: CodeBlockMode = .progressive,
        transition: any MarkdownStreamingTransition = .opacity
    ) {
        self.tables = tables
        self.codeBlocks = codeBlocks
        self.transition = transition
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tables == rhs.tables && lhs.codeBlocks == rhs.codeBlocks && lhs.transition.isEqual(to: rhs.transition)
    }

    var plugin: AnyMarkdownStreamingPlugin {
        AnyMarkdownStreamingPlugin(StreamingPlugin(options: self))
    }
}

struct StreamingPlugin: MarkdownStreamingPlugin {
    let options: MarkdownStreamingOptions

    var transition: (any ViewTransition)? {
        options.transition.viewTransition
    }

    func makeSession(inputs: MarkdownRenderInputs) -> any MarkdownStreamingSession {
        StreamingRenderSession(inputs: inputs)
    }
}

public extension EnvironmentValues {
    var markdownStreaming: MarkdownStreamingOptions? {
        get { (markdownStreamingPlugin?.base as? StreamingPlugin)?.options }
        set { markdownStreamingPlugin = newValue?.plugin }
    }
}

public extension View {
    func markdownStreaming(
        _ isStreaming: Bool = true,
        tables: MarkdownStreamingOptions.TableMode = .progressive,
        codeBlocks: MarkdownStreamingOptions.CodeBlockMode = .progressive,
        transition: any MarkdownStreamingTransition = .opacity
    ) -> some View {
        environment(
            \.markdownStreaming,
            isStreaming ? MarkdownStreamingOptions(tables: tables, codeBlocks: codeBlocks, transition: transition) : nil
        )
    }
}
