import Foundation

extension Bundle {
    /// Sample document rendered by the Text screen.
    var sampleMarkdown: String {
        guard
            let url = url(forResource: "sample_markdown", withExtension: "md"),
            let content = try? String(contentsOf: url, encoding: .utf8)
        else {
            return ""
        }
        return content
    }

    /// `file://` URI for a bundled image, used to insert image markdown in the playground.
    func imageURI(named name: String, extension ext: String) -> String? {
        url(forResource: name, withExtension: ext)?.absoluteString
    }
}
