import SwiftUI

private struct HomeMenuItem {
    let route: ExampleRoute
    let label: String
    let subtext: String
    let color: Color
    let accessibilityId: String
}

private let menuItems: [HomeMenuItem] = [
    HomeMenuItem(
        route: .playground,
        label: "Playground",
        subtext: "live editor with preview",
        color: .tileBlue,
        accessibilityId: "home-block-playground"
    ),
    HomeMenuItem(
        route: .text,
        label: "Text",
        subtext: "static markdown rendering",
        color: .tileGreen,
        accessibilityId: "home-block-text"
    ),
    HomeMenuItem(
        route: .input,
        label: "Input",
        subtext: "chat-style rich text input",
        color: .tileOrange,
        accessibilityId: "home-block-input"
    ),
    HomeMenuItem(
        route: .stream,
        label: "Stream",
        subtext: "streaming markdown with tables",
        color: .tilePurple,
        accessibilityId: "home-block-stream"
    ),
    HomeMenuItem(
        route: .storybook,
        label: "Storybook",
        subtext: "component stories",
        color: .tilePink,
        accessibilityId: "home-block-storybook"
    ),
]

struct HomeScreen: View {
    // MARK: - Properties

    let onNavigate: (ExampleRoute) -> Void

    // MARK: - Views

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Enriched Markdown Examples")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("Explore different markdown rendering and input capabilities")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 40)

                VStack(spacing: 0) {
                    ForEach(menuItems.indices, id: \.self) { index in
                        let item = menuItems[index]
                        HomeScreenButton(
                            label: item.label,
                            subtext: item.subtext,
                            color: item.color,
                            accessibilityId: item.accessibilityId
                        ) {
                            onNavigate(item.route)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(Color.homeBackground)
        .accessibilityIdentifier("home-screen")
    }
}

// MARK: -

#Preview {
    HomeScreen(onNavigate: { _ in })
}
