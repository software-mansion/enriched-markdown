import SwiftUI

struct SetMarkdownSheet: View {
    // MARK: - Properties

    @Binding var rawInput: String
    let onCancel: () -> Void
    let onConfirm: () -> Void

    // MARK: - Views

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set Raw Markdown")
                    .font(.system(size: 16, weight: .semibold))

                editor

                HStack(spacing: 8) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("set-markdown-cancel")

                    Spacer()

                    Button("Set", action: onConfirm)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.brandNavy)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.brandMint, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityIdentifier("set-markdown-confirm")
                }
            }
            .padding(16)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
    }

    private var editor: some View {
        TextEditor(text: $rawInput)
            .frame(minHeight: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray300, lineWidth: 1)
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
    }
}

// MARK: -

#Preview {
    SetMarkdownSheet(rawInput: .constant(""), onCancel: {}, onConfirm: {})
}
