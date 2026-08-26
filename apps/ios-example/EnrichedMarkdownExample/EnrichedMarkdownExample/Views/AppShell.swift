import EnrichedMarkdown
import SwiftUI

struct AppShell: View {
    // MARK: - Properties

    @State private var path: [ExampleRoute] = []
    @State private var unavailableRouteName: String?
    @State private var sampleMarkdown = ""

    // MARK: - Views

    var body: some View {
        NavigationStack(path: $path) {
            HomeScreen(onNavigate: handleNavigate)
                .brandedNavigationBar(title: ExampleRoute.home.title)
                .navigationDestination(for: ExampleRoute.self) { route in
                    destination(for: route)
                        .brandedNavigationBar(title: route.title)
                }
        }
        .tint(Color.brandNavy)
        .onAppear {
            if sampleMarkdown.isEmpty {
                sampleMarkdown = Bundle.main.sampleMarkdown
            }
        }
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
        case .home, .input, .stream, .storybook:
            EmptyView()
        }
    }

    // MARK: - Methods

    private func handleNavigate(_ target: ExampleRoute) {
        switch target {
        case .playground, .text:
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
