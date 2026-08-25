enum ExampleRoute {
    case home
    case playground
    case text
    case input
    case stream
    case storybook

    var title: String {
        switch self {
        case .home: return "Enriched Markdown Examples"
        case .playground: return "Playground"
        case .text: return "Text"
        case .input: return "Input"
        case .stream: return "Stream"
        case .storybook: return "Storybook"
        }
    }
}
