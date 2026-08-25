import SwiftUI

@main
struct EnrichedMarkdownExampleApp: App {
    init() {
        ExampleFontRegistrar.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            AppShell()
        }
    }
}
