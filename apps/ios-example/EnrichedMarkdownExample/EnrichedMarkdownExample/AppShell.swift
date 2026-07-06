import EnrichedMarkdown
import SwiftUI

struct AppShell: View {
    @State private var route: ExampleRoute = .home
    @State private var unavailableRouteName: String?
    @State private var sampleMarkdown = ""

    private var navigationTitle: String {
        switch route {
        case .home:
            return "Enriched Markdown Examples"
        case .playground:
            return "Playground"
        case .text:
            return "Text"
        case .input, .stream, .storybook:
            return routeName(route)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch route {
                case .home:
                    HomeScreen(onNavigate: handleNavigate)
                case .playground:
                    PlaygroundScreen()
                case .text:
                    TextScreen(markdown: sampleMarkdown)
                case .input, .stream, .storybook:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.toolbarBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                if route != .home {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            route = .home
                        }
                        .foregroundStyle(AppColors.toolbarForeground)
                    }
                }
            }
        }
        .tint(AppColors.toolbarForeground)
        .onAppear {
            if sampleMarkdown.isEmpty {
                sampleMarkdown = BundleLoader.sampleMarkdown
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

    private func handleNavigate(_ target: ExampleRoute) {
        switch target {
        case .playground, .text:
            route = target
        case .input, .stream, .storybook:
            unavailableRouteName = routeName(target)
        case .home:
            route = .home
        }
    }

    private func routeName(_ route: ExampleRoute) -> String {
        switch route {
        case .home: return "Home"
        case .playground: return "Playground"
        case .text: return "Text"
        case .input: return "Input"
        case .stream: return "Stream"
        case .storybook: return "Storybook"
        }
    }
}

private enum AppColors {
    static let toolbarBackground = Color(red: 190 / 255, green: 235 / 255, blue: 208 / 255)
    static let toolbarForeground = Color(red: 0 / 255, green: 26 / 255, blue: 114 / 255)
}

private enum BundleLoader {
    static var sampleMarkdown: String {
        guard
            let url = Bundle.main.url(forResource: "sample_markdown", withExtension: "md"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return ""
        }
        return content
    }
}
