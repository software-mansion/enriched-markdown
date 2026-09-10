public extension MarkdownASTNode {
    func first(ofType type: NodeType) -> MarkdownASTNode? {
        if self.type == type {
            return self
        }

        for child in children {
            if let match = child.first(ofType: type) {
                return match
            }
        }

        return nil
    }

    func all(ofType type: NodeType) -> [MarkdownASTNode] {
        var result: [MarkdownASTNode] = []
        collectNodes(ofType: type, into: &result)
        return result
    }

    func child(ofType type: NodeType) -> MarkdownASTNode? {
        children.first { $0.type == type }
    }

    /// The node's content and its descendants' text, in document order.
    package func flattenedText() -> String {
        var buffer = ""
        appendFlattenedText(to: &buffer)
        return buffer
    }

    private func appendFlattenedText(to buffer: inout String) {
        buffer.append(content)
        for child in children {
            child.appendFlattenedText(to: &buffer)
        }
    }

    private func collectNodes(ofType type: NodeType, into result: inout [MarkdownASTNode]) {
        if self.type == type {
            result.append(self)
        }

        for child in children {
            child.collectNodes(ofType: type, into: &result)
        }
    }
}
