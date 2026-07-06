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
        color: Color(red: 0 / 255, green: 122 / 255, blue: 255 / 255),
        accessibilityId: "home-block-playground"
    ),
    HomeMenuItem(
        route: .text,
        label: "Text",
        subtext: "static markdown rendering",
        color: Color(red: 52 / 255, green: 199 / 255, blue: 89 / 255),
        accessibilityId: "home-block-text"
    ),
    HomeMenuItem(
        route: .input,
        label: "Input",
        subtext: "chat-style rich text input",
        color: Color(red: 255 / 255, green: 149 / 255, blue: 0 / 255),
        accessibilityId: "home-block-input"
    ),
    HomeMenuItem(
        route: .stream,
        label: "Stream",
        subtext: "streaming markdown with tables",
        color: Color(red: 175 / 255, green: 82 / 255, blue: 222 / 255),
        accessibilityId: "home-block-stream"
    ),
    HomeMenuItem(
        route: .storybook,
        label: "Storybook",
        subtext: "component stories",
        color: Color(red: 255 / 255, green: 45 / 255, blue: 85 / 255),
        accessibilityId: "home-block-storybook"
    ),
]

struct HomeScreen: View {
    let onNavigate: (ExampleRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("Enriched Markdown Examples")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 10)

                Text("Explore different markdown rendering and input capabilities")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(red: 102 / 255, green: 102 / 255, blue: 102 / 255))
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
        .background(Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255))
        .accessibilityIdentifier("home-screen")
    }
}
