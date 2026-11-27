#pragma once
#import <Foundation/Foundation.h>

@class MarkdownASTNode;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

/// Serializes an AST node (and its children) back to markdown syntax.
/// Handles inline elements: strong, emphasis, strikethrough, underline, code, links, images.
NSString *markdownFromASTNode(MarkdownASTNode *node);

/// Serializes only the children of a node to markdown (skipping the node itself).
/// Useful for extracting the markdown content of a container node (e.g. a table cell).
NSString *markdownFromASTNodeChildren(MarkdownASTNode *node);

/// Serializes a table cell's content on one line: a line ending inside it (decoded from `&#10;` or `&#13;`)
/// goes back to that entity, so it no longer ends the row.
/// A break node can't reach a cell yet; once it can (#1037), it needs `<br>` instead.
NSString *markdownFromTableCellNode(MarkdownASTNode *node);

/// Serializes a Blockquote or Admonition node to full markdown, including `> ` line
/// prefixes and `> [!TYPE]` header for admonitions.
NSString *markdownFromBlockquoteNode(MarkdownASTNode *node);

/// Extracts plain text content from an AST node recursively (no markdown syntax).
NSString *plainTextFromASTNode(MarkdownASTNode *node);

/// Like plainTextFromASTNode, with each link as `[label](url)` (`copyLinksAs: 'markdown'`); autolinks stay as their text.
NSString *plainTextWithMarkdownLinksFromASTNode(MarkdownASTNode *node);

/// `[label](url)`, escaping only what would break the link; an autolink (the label is the URL) stays as its label.
NSString *ENRMMarkdownLink(NSString *label, NSString *url);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
