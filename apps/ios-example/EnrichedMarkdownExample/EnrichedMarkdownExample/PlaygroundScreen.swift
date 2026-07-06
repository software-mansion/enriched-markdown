import EnrichedMarkdown
import SwiftUI

struct PlaygroundScreen: View {
    @State private var markdown = ""
    @State private var setMarkdownSheetVisible = false
    @State private var rawInput = ""
    @State private var blockImageURI: String?
    @State private var inlineImageURI: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {}
                    PlaygroundButton(label: "Underline", accessibilityId: "underline-button") {}
                }

                HStack(spacing: 8) {
                    PlaygroundButton(label: "Insert Image", accessibilityId: "insert-image-button") {
                        guard let uri = blockImageURI else { return }
                        let imageMarkdown = "![logo](\(uri))"
                        if markdown.isEmpty {
                            markdown = imageMarkdown
                        } else {
                            markdown += "\n\n\(imageMarkdown)"
                        }
                    }
                    PlaygroundButton(label: "Insert Inline Image", accessibilityId: "insert-inline-image-button") {
                        guard let uri = inlineImageURI else { return }
                        markdown = "Enriched Markdown is a library for ![icon](\(uri)) React Native."
                    }
                }

                Button {
                    rawInput = ""
                    setMarkdownSheetVisible = true
                } label: {
                    Text("Set Raw Markdown")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0 / 255, green: 26 / 255, blue: 114 / 255))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Color(red: 190 / 255, green: 235 / 255, blue: 208 / 255),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("set-markdown-button")

                Text("Preview")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255))

                Group {
                    if markdown.isEmpty {
                        Text("Preview will appear here")
                            .font(.body.italic())
                            .foregroundStyle(Color(red: 156 / 255, green: 163 / 255, blue: 175 / 255))
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
                        .stroke(Color(red: 209 / 255, green: 213 / 255, blue: 219 / 255), lineWidth: 1)
                )
                .accessibilityIdentifier("preview-container")
            }
            .padding(16)
        }
        .background(Color(red: 249 / 255, green: 250 / 255, blue: 251 / 255))
        .accessibilityIdentifier("playground-screen")
        .markdownTheme(PlaygroundMarkdownTheme)
        .onAppear {
            blockImageURI = BundleImageLoader.fileURI(named: "logo", extension: "png")
            inlineImageURI = BundleImageLoader.fileURI(named: "logo_icon", extension: "png")
        }
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
}

private struct PlaygroundButton: View {
    let label: String
    let accessibilityId: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(red: 55 / 255, green: 65 / 255, blue: 81 / 255))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Color(red: 229 / 255, green: 231 / 255, blue: 235 / 255),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }
}

private struct SetMarkdownSheet: View {
    @Binding var rawInput: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set Raw Markdown")
                    .font(.system(size: 16, weight: .semibold))

                TextEditor(text: $rawInput)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(red: 209 / 255, green: 213 / 255, blue: 219 / 255), lineWidth: 1)
                    )
                    .accessibilityIdentifier("set-markdown-input")
                    .overlay(alignment: .topLeading) {
                        if rawInput.isEmpty {
                            Text("Paste or type markdown...")
                                .foregroundStyle(Color.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .allowsHitTesting(false)
                        }
                    }

                HStack(spacing: 8) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("set-markdown-cancel")

                    Spacer()

                    Button("Set", action: onConfirm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(red: 0 / 255, green: 26 / 255, blue: 114 / 255))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Color(red: 190 / 255, green: 235 / 255, blue: 208 / 255),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .accessibilityIdentifier("set-markdown-confirm")
                }
            }
            .padding(16)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }
}

private enum BundleImageLoader {
    static func fileURI(named name: String, extension ext: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            return nil
        }
        return url.absoluteString
    }
}
