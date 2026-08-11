import EnrichedMarkdown
import SwiftUI

struct PlaygroundScreen: View {
    // MARK: - Properties

    @StateObject private var controller = MarkdownEditorController()

    @State private var markdown: String = ""
    @State private var underlineEnabled: Bool = true
    @State private var setMarkdownSheetVisible: Bool = false
    @State private var rawInput: String = ""
    @State private var blockImageURI: String?
    @State private var inlineImageURI: String?
    @State private var markdownAlertVisible: Bool = false
    @State private var markdownAlertText: String = ""

    // MARK: - Views

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {
                        controller.blur()
                    }
                    PlaygroundButton(
                        label: "Underline",
                        accessibilityId: "underline-button",
                        isActive: underlineEnabled
                    ) {
                        underlineEnabled.toggle()
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

                setMarkdownButton
                preview
                editor
            }
            .padding(16)
        }
        .background(Color.gray50)
        .accessibilityIdentifier("playground-screen")
        .markdownTheme(PlaygroundMarkdownTheme)
        .markdownSelectionMenu(MarkdownSelectionMenuConfig())
        .onAppear(perform: loadBundledImages)
        .sheet(isPresented: $setMarkdownSheetVisible) {
            SetMarkdownSheet(
                rawInput: $rawInput,
                onCancel: { setMarkdownSheetVisible = false },
                onConfirm: {
                    markdown = rawInput
                    controller.setMarkdown(rawInput)
                    setMarkdownSheetVisible = false
                }
            )
        }
        .alert("Markdown", isPresented: $markdownAlertVisible) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(markdownAlertText)
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

    private var editor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Editor")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.gray400)

            EnrichedMarkdownTextInput(controller: controller, placeholder: "Type markdown here…")
                .onMarkdownChange { markdown = $0 }
                .frame(height: 160)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray300, lineWidth: 1)
                )
                .accessibilityIdentifier("editor-container")

            HStack(spacing: 8) {
                PlaygroundButton(label: "Focus", accessibilityId: "focus-button") {
                    controller.focus()
                }
                PlaygroundButton(label: "Clear", accessibilityId: "clear-button") {
                    controller.clear()
                    markdown = ""
                }
                PlaygroundButton(label: "Get Markdown", accessibilityId: "get-markdown-button") {
                    markdownAlertText = controller.getMarkdown()
                    markdownAlertVisible = true
                }
            }
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
