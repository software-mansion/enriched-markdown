import EnrichedMarkdown
import SwiftUI

struct PlaygroundScreen: View {
    // MARK: - Properties

    @State private var markdown = ""
    @State private var setMarkdownSheetVisible = false
    @State private var rawInput = ""
    @State private var blockImageURI: String?
    @State private var inlineImageURI: String?

    // MARK: - Views

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {}
                    PlaygroundButton(label: "Underline", accessibilityId: "underline-button") {}
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Image", accessibilityId: "insert-image-button") {
                        insertBlockImage()
                    }
                    PlaygroundButton(label: "Insert Inline Image", accessibilityId: "insert-inline-image-button") {
                        insertInlineImage()
                    }
                }

                setMarkdownButton
                preview
            }
            .padding(16)
        }
        .background(Color.gray50)
        .accessibilityIdentifier("playground-screen")
        .markdownTheme(PlaygroundMarkdownTheme)
        .onAppear(perform: loadBundledImages)
        .sheet(isPresented: $setMarkdownSheetVisible) {
            SetMarkdownSheet(
                rawInput: $rawInput,
                onCancel: { setMarkdownSheetVisible = false },
                onConfirm: {
                    markdown = rawInput
                    setMarkdownSheetVisible = false
                }
            )
        }
    }

    private var setMarkdownButton: some View {
        Button("Set Raw Markdown") {
            rawInput = ""
            setMarkdownSheetVisible = true
        }
        .buttonStyle(.pillPrimary)
        .accessibilityIdentifier("set-markdown-button")
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gray400)

            Group {
                if markdown.isEmpty {
                    Text("Preview will appear here")
                        .font(.body.italic())
                        .foregroundStyle(Color.gray400)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .accessibilityIdentifier("preview-empty")
                } else {
                    EnrichedMarkdownText(markdown)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .accessibilityIdentifier("preview-text")
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray300, lineWidth: 1)
            )
            .accessibilityIdentifier("preview-container")
        }
    }

    // MARK: - Methods

    private func loadBundledImages() {
        blockImageURI = Bundle.main.imageURI(named: "logo", extension: "png")
        inlineImageURI = Bundle.main.imageURI(named: "logo_icon", extension: "png")
    }

    private func insertBlockImage() {
        guard let uri = blockImageURI else { return }
        let imageMarkdown = "![logo](\(uri))"
        if markdown.isEmpty {
            markdown = imageMarkdown
        } else {
            markdown += "\n\n\(imageMarkdown)"
        }
    }

    private func insertInlineImage() {
        guard let uri = inlineImageURI else { return }
        markdown = "Enriched Markdown is a library for ![icon](\(uri)) React Native."
    }
}

// MARK: -

#Preview {
    PlaygroundScreen()
}
