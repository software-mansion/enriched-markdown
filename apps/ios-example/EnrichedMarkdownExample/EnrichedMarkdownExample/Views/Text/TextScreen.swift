import EnrichedMarkdown
import SwiftUI

struct TextScreen: View {
    // MARK: - Properties

    let markdown: String

    @State private var pressedLink: URL?
    @State private var linkAlertVisible: Bool = false

    // MARK: - Views

    var body: some View {
        ScrollView {
            EnrichedMarkdownText(markdown, flags: Md4cFlags(superscript: true, subscript: true))
                .markdownTheme(CustomMarkdownTheme)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .onLinkPress { url in
                    pressedLink = url
                    linkAlertVisible = true
                }
        }
        .background(Color.white)
        .markdownSelectionColor(Color.selectionPurple)
        .alert("Link Pressed!", isPresented: $linkAlertVisible, presenting: pressedLink) { url in
            Button("Open in Browser") {
                UIApplication.shared.open(url)
            }
            Button("Cancel", role: .cancel) {}
        } message: { url in
            Text("You tapped on: \(url.absoluteString)")
        }
    }
}

// MARK: -

#Preview {
    TextScreen(markdown: Bundle.main.sampleMarkdown)
}
