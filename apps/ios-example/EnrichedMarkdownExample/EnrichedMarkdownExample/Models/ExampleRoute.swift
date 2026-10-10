enum ExampleRoute {
    case home
    case playground
    case text
    case math
    case spoilers
    case blur
    case hogwarts
    case input
    case stream
    case storybook

    var title: String {
        switch self {
        case .home: return "Enriched Markdown Examples"
        case .playground: return "Playground"
        case .text: return "Text"
        case .math: return "Math"
        case .spoilers: return "Spoilers"
        case .blur: return "Blur"
        case .hogwarts: return "Hogwarts"
        case .input: return "Input"
        case .stream: return "Stream"
        case .storybook: return "Storybook"
        }
    }

    /// Screens that draw their own full-bleed backdrop get a transparent bar
    /// instead of the branded mint one.
    var paintsOwnBackdrop: Bool {
        self == .spoilers || self == .blur || self == .hogwarts
    }
}
