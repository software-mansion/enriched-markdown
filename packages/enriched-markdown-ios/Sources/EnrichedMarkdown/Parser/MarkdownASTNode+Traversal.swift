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

    private func collectNodes(ofType type: NodeType, into result: inout [MarkdownASTNode]) {
        if self.type == type {
            result.append(self)
        }

        for child in children {
            child.collectNodes(ofType: type, into: &result)
        }
    }
}
