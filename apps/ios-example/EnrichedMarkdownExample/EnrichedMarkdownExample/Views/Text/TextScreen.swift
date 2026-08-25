import EnrichedMarkdown
import SwiftUI

struct TextScreen: View {
    // MARK: - Properties

    let markdown: String

    // MARK: - Views

    var body: some View {
        ScrollView {
            EnrichedMarkdownText(markdown)
                .markdownTheme(CustomMarkdownTheme)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .onLinkPress { url in
                    UIApplication.shared.open(url)
                }
        }
        .background(Color.white)
    }
}

// MARK: -

#Preview {
    TextScreen(markdown: Bundle.main.sampleMarkdown)
}
