import EnrichedMarkdown
import SwiftUI

struct AppShell: View {
    // MARK: - Properties

    @State private var path: [ExampleRoute] = []
    @State private var unavailableRouteName: String?
    @State private var sampleMarkdown: String = Bundle.main.sampleMarkdown

    // MARK: - Views

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(onNavigate: handleNavigate)
                .brandedNavigationBar(title: ExampleRoute.home.title)
                .navigationDestination(for: ExampleRoute.self) { route in
                    if route.paintsOwnBackdrop {
                        destination(for: route)
                            .immersiveNavigationBar()
                    } else {
                        destination(for: route)
                            .brandedNavigationBar(title: route.title)
                    }
                }
        }
        .tint(Color.brandNavy)
        .alert(
            unavailableRouteName.map { "\($0) is not available on iOS yet" } ?? "",
            isPresented: Binding(
                get: { unavailableRouteName != nil },
                set: { if !$0 { unavailableRouteName = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        }
    }

    @ViewBuilder
    private func destination(for route: ExampleRoute) -> some View {
        switch route {
        case .playground:
            PlaygroundScreen()
        case .text:
            TextScreen(markdown: sampleMarkdown)
        case .math:
            MathScreen()
        case .spoilers:
            SpoilersScreen()
        case .blur:
            BlurScreen()
        case .hogwarts:
            HogwartsScreen()
        case .home, .input, .stream, .storybook:
            EmptyView()
        }
    }

    // MARK: - Methods

    private func handleNavigate(_ target: ExampleRoute) {
        switch target {
        case .playground, .text, .math, .spoilers, .blur, .hogwarts:
            path.append(target)
        case .input, .stream, .storybook:
            unavailableRouteName = target.title
        case .home:
            path = []
        }
    }
}

// MARK: -

#Preview {
    AppShell()
}

