import UIKit

/// The text properties every block or inline style record shares, so a
/// `MarkdownThemeElement` writes them with one generic `applyTextStyle`.
package protocol TextStyleRecord {
    var font: UIFont? { get set }
    var foregroundColor: UIColor? { get set }
    var marginTop: CGFloat? { get set }
    var marginBottom: CGFloat? { get set }
    var lineHeight: CGFloat? { get set }
}

/// A record whose renderer honors a paragraph alignment.
package protocol AlignableTextStyleRecord: TextStyleRecord {
    var textAlignment: NSTextAlignment? { get set }
}

extension ElementStyle: AlignableTextStyleRecord {}
extension CodeBlockStyle: AlignableTextStyleRecord {}
extension BlockquoteStyle: TextStyleRecord {}
extension ListStyle: TextStyleRecord {}
extension TableStyle: TextStyleRecord {}
