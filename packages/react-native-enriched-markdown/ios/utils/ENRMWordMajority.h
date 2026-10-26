#import <Foundation/Foundation.h>

@class MarkdownASTNode;
@class StyleConfig;

NS_ASSUME_NONNULL_BEGIN

__BEGIN_DECLS

/// AST attribute holding the resolved prose direction (@"ltr" / @"rtl") of a block.
/// Internal metadata; never serialized back into markdown.
extern NSString *const ENRMProseDirectionKey;

/// Direction of most words in `text`; each word votes by its first letter and a
/// tie goes to the first word. nil when the text has no letters.
NSString *_Nullable ENRMWordMajorityDirection(NSString *text);

/// A copy of `root` with ENRMProseDirectionKey on every block, list item, inline
/// code span and table cell. Lists and quotes share one direction; table cells
/// resolve on their own. Inline code and link pills don't vote.
MarkdownASTNode *ENRMWordMajorityAST(MarkdownASTNode *root, StyleConfig *config);

__END_DECLS

NS_ASSUME_NONNULL_END
