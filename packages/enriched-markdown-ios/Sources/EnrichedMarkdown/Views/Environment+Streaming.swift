import SwiftUI

private struct MarkdownStreamingPluginKey: EnvironmentKey {
    static let defaultValue: AnyMarkdownStreamingPlugin? = nil
}

package extension EnvironmentValues {
    var markdownStreamingPlugin: AnyMarkdownStreamingPlugin? {
        get { self[MarkdownStreamingPluginKey.self] }
        set { self[MarkdownStreamingPluginKey.self] = newValue }
    }
}
