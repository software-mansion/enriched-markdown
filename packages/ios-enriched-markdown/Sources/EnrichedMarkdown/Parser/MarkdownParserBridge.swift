import EnrichedMarkdownCppShim
import Foundation

enum MarkdownParserBridge {
    static func parse(_ markdown: String, flags: Md4cFlags) -> MarkdownASTNode {
        if isBlank(markdown) {
            return MarkdownASTNode(type: .document)
        }

        return markdown.withCString { cString in
            guard let result = em_parse_markdown(
                cString,
                flags.underline ? 1 : 0,
                flags.latexMath ? 1 : 0,
                flags.superscript ? 1 : 0,
                flags.subscript ? 1 : 0,
                flags.highlight ? 1 : 0,
                flags.permissiveAutolinks ? 1 : 0
            ) else {
                return MarkdownASTNode(type: .document)
            }
            defer { em_parse_result_release(result) }

            guard let root = em_ast_root(result) else {
                return MarkdownASTNode(type: .document)
            }

            return convertNode(root)
        }
    }

    private static func isBlank(_ markdown: String) -> Bool {
        markdown.isEmpty || markdown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func convertNode(_ nodePointer: UnsafeRawPointer) -> MarkdownASTNode {
        var attributes: [String: String] = [:]
        if let attributeIterator = em_ast_node_attribute_iterator_create(nodePointer) {
            defer { em_ast_node_attribute_iterator_release(attributeIterator) }

            var keyPointer: UnsafePointer<CChar>?
            var valuePointer: UnsafePointer<CChar>?
            while em_ast_node_attribute_iterator_next(attributeIterator, &keyPointer, &valuePointer) != 0 {
                guard let keyPointer, let valuePointer else { continue }
                attributes[String(cString: keyPointer)] = String(cString: valuePointer)
            }
        }

        var children: [MarkdownASTNode] = []
        let childCount = em_ast_node_child_count(nodePointer)
        if childCount > 0 {
            children.reserveCapacity(Int(childCount))
            for index in 0..<childCount {
                if let child = em_ast_node_child_at(nodePointer, index) {
                    children.append(convertNode(child))
                }
            }
        }

        let rawType = em_ast_node_type(nodePointer)
        let content = String(cString: em_ast_node_content(nodePointer))
        return MarkdownASTNode(
            type: NodeType(rawValue: Int(rawType)) ?? .document,
            content: content,
            attributes: attributes,
            children: children
        )
    }
}
