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
                    // The article dresses its own navigation bar to match the
                    // page it is printed on; every other screen wears the mint.
                    if route == .article {
                        destination(for: route)
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
        case .article:
            ArticleScreen(article: .featured)
        case .math:
            MathScreen()
        case .home, .input, .stream, .storybook:
            EmptyView()
        }
    }

    // MARK: - Methods

    private func handleNavigate(_ target: ExampleRoute) {
        switch target {
        case .playground, .text, .article, .math:
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
