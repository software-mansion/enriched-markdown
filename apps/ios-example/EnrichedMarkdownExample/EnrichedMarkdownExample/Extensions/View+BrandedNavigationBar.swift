import SwiftUI

extension View {
    /// Shared mint navigation bar applied to every screen in the example app.
    func brandedNavigationBar(title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.brandMint, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
    }

    /// Chrome for a screen that paints its own full-bleed backdrop: no bar
    /// background or title, so the backdrop runs under the status bar, and a
    /// white back button in place of the tinted system one.
    func immersiveNavigationBar() -> some View {
        navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    ImmersiveBackButton()
                }
            }
    }
}

private struct ImmersiveBackButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                Text("Back")
                    .font(.system(size: 17))
            }
            .foregroundStyle(Color.white)
        }
        .accessibilityIdentifier("immersive-back-button")
    }
}
