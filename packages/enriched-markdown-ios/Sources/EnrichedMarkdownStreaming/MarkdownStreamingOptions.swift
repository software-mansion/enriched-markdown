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

    public enum MediaMode: Equatable, Sendable {
        case progressive
        case hidden
    }

    public var tables: TableMode
    public var codeBlocks: CodeBlockMode
    public var media: MediaMode
    public var transition: any MarkdownStreamingTransition

    public init(
        tables: TableMode = .progressive,
        codeBlocks: CodeBlockMode = .progressive,
        media: MediaMode = .progressive,
        transition: any MarkdownStreamingTransition = .opacity
    ) {
        self.tables = tables
        self.codeBlocks = codeBlocks
        self.media = media
        self.transition = transition
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.tables == rhs.tables && lhs.codeBlocks == rhs.codeBlocks && lhs.media == rhs.media && lhs.transition.isEqual(to: rhs.transition)
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
        media: MarkdownStreamingOptions.MediaMode = .progressive,
        transition: any MarkdownStreamingTransition = .opacity
    ) -> some View {
        environment(
            \.markdownStreaming,
            isStreaming ? MarkdownStreamingOptions(tables: tables, codeBlocks: codeBlocks, media: media, transition: transition) : nil
        )
    }
}
