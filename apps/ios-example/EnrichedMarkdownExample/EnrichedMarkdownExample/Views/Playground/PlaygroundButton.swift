import SwiftUI

struct PlaygroundButton: View {
    // MARK: - Properties

    let label: String
    let accessibilityId: String
    let action: () -> Void

    // MARK: - Views

    var body: some View {
        Button(label, action: action)
            .buttonStyle(.pillSecondary)
            .accessibilityIdentifier(accessibilityId)
    }
}

// MARK: -

#Preview {
    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {}
        .padding()
}
