import EnrichedMarkdown
import SwiftUI

struct PlaygroundScreen: View {
    // MARK: - Properties

    @State private var markdown: String = ""
    @State private var underlineEnabled: Bool = true
    @State private var selectableEnabled: Bool = true
    @State private var setMarkdownSheetVisible: Bool = false
    @State private var rawInput: String = ""
    @State private var blockImageURI: String?
    @State private var inlineImageURI: String?
    @State private var longPressedLink: String = ""
    @State private var linkAlertVisible: Bool = false
    @State private var acceptImageType: String = "image/png"

    // MARK: - Views

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {}
                    PlaygroundButton(
                        label: "Underline",
                        accessibilityId: "underline-button",
                        isActive: underlineEnabled
                    ) {
                        underlineEnabled.toggle()
                    }
                    PlaygroundButton(
                        label: "Selectable",
                        accessibilityId: "selectable-button",
                        isActive: selectableEnabled
                    ) {
                        selectableEnabled.toggle()
                    }
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Image", accessibilityId: "insert-image-button") {
                        insertBlockImage()
                    }
                    PlaygroundButton(label: "Insert Inline Image", accessibilityId: "insert-inline-image-button") {
                        insertInlineImage()
                    }
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Header Image", accessibilityId: "insert-header-image-button") {
                        insertHeaderImage()
                    }
                    PlaygroundButton(
                        label: "Accept: \(acceptImageType == "image/png" ? "PNG" : "JPEG")",
                        accessibilityId: "accept-header-button",
                        isActive: acceptImageType == "image/png"
                    ) {
                        acceptImageType = acceptImageType == "image/png" ? "image/jpeg" : "image/png"
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
        .markdownSelectionMenu(MarkdownSelectionMenuConfig())
        .markdownSelectable(selectableEnabled)
        .markdownSelectionColor(.orange)
        .markdownImageRequestHeaders(["Accept": acceptImageType])
        .onLinkLongPress { url in
            longPressedLink = url.absoluteString
            linkAlertVisible = true
        }
        .alert("Link long-pressed", isPresented: $linkAlertVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(longPressedLink)
        }
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
                    EnrichedMarkdownText(markdown, flags: Md4cFlags(underline: underlineEnabled))
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

    // httpbingo.org negotiates the response image from the Accept header (and
    // rejects requests without one), so this image only renders because
    // markdownImageRequestHeaders reaches the wire — and toggling the header
    // shows a different image for the same URL via the header-aware cache.
    private func insertHeaderImage() {
        let imageMarkdown = "![header image](https://httpbingo.org/image)"
        if markdown.isEmpty {
            markdown = imageMarkdown
        } else {
            markdown += "\n\n\(imageMarkdown)"
        }
    }
}

// MARK: -

#Preview {
    PlaygroundScreen()
}
