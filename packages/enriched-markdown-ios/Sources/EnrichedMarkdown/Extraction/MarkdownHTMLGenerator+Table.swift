import UIKit

extension MarkdownHTMLGenerator {
    static func appendTable(_ table: TableAttachment, into html: inout String) {
        html += "<table style=\"border-collapse: collapse;\">"
        for row in table.model.rows {
            html += "<tr>"
            for cell in row {
                let tag = cell.isHeader ? "th" : "td"
                html += "<\(tag) style=\"border: 1px solid #d0d0d0; "
                    + "padding: 4px 8px; text-align: left;\">"
                    + escapeHTML(cell.plainText)
                    + "</\(tag)>"
            }
            html += "</tr>"
        }
        html += "</table>"
    }

    static func escapeHTML(_ text: String) -> String {
        guard text.contains(where: { "&<>\"'".contains($0) }) else { return text }
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
