import SwiftUI

struct HomeScreenButton: View {
    // MARK: - Properties

    let label: String
    let subtext: String
    let color: Color
    let accessibilityId: String
    let action: () -> Void

    // MARK: - Views

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)

                Text(subtext)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .padding(.vertical, 10)
        .accessibilityIdentifier(accessibilityId)
    }
}

// MARK: -

#Preview {
    HomeScreenButton(
        label: "Playground",
        subtext: "live editor with preview",
        color: .tileBlue,
        accessibilityId: "home-block-playground"
    ) {}
    .padding()
}
