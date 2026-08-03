import SwiftUI

/// Full-width rounded button used across the playground UI.
struct PillButtonStyle: ButtonStyle {
    let foreground: Color
    let background: Color
    let fontSize: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(background, in: RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == PillButtonStyle {
    static var pillPrimary: PillButtonStyle {
        PillButtonStyle(foreground: .brandNavy, background: .brandMint, fontSize: 14)
    }

    static var pillSecondary: PillButtonStyle {
        PillButtonStyle(foreground: .gray700, background: .gray200, fontSize: 13)
    }

    static var pillSecondaryActive: PillButtonStyle {
        PillButtonStyle(foreground: .brandNavy, background: .brandMint, fontSize: 13)
    }
}
