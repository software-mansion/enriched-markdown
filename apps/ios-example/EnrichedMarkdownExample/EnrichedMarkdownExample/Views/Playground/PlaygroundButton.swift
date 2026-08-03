import SwiftUI

struct PlaygroundButton: View {
    // MARK: - Properties

    let label: String
    let accessibilityId: String
    var isActive: Bool = false
    let action: () -> Void

    // MARK: - Views

    var body: some View {
        Button(label, action: action)
            .buttonStyle(isActive ? .pillSecondaryActive : .pillSecondary)
            .accessibilityIdentifier(accessibilityId)
    }
}

// MARK: -

#Preview {
    PlaygroundButton(label: "Blur", accessibilityId: "blur-button") {}
        .padding()
}
