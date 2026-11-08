#import "MarkdownASTNode.h"
#import <Foundation/Foundation.h>

@interface ENRMMd4cFlags : NSObject <NSCopying>

@property (nonatomic, assign) BOOL underline;
@property (nonatomic, assign) BOOL latexMath;
@property (nonatomic, assign) BOOL superscript;
@property (nonatomic, assign) BOOL subscript;
@property (nonatomic, assign) BOOL strikethrough;
@property (nonatomic, assign) BOOL highlight;
@property (nonatomic, assign) BOOL hardSoftBreaks;
@property (nonatomic, assign) BOOL preserveBlankLines;
@property (nonatomic, assign) BOOL admonitions;

+ (instancetype)defaultFlags;

@end

#ifdef __cplusplus
#include "MD4CParser.hpp"
/// The core parser's flags for `flags`.
Markdown::Md4cFlags ENRMCoreMd4cFlags(ENRMMd4cFlags *flags);
#endif

@class ENRMLinkRegexConfig;

@interface ENRMMarkdownParser : NSObject

- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown;
- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown flags:(ENRMMd4cFlags *)flags;
- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown flags:(ENRMMd4cFlags *)flags isGFM:(BOOL)isGFM;
// Recognition runs before returning the AST to renderers and measurement.
- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown
                             flags:(ENRMMd4cFlags *)flags
                             isGFM:(BOOL)isGFM
                         linkRegex:(ENRMLinkRegexConfig *)linkRegex
               inlineCodeLinkRegex:(ENRMLinkRegexConfig *)inlineCodeLinkRegex;
// activeBlockSlotIds: the block slots a React child stands in for; their nodes get
// the `blockSlotId`/`blockSlotKind` attributes. annotateImages stamps every image
// with its `imageOccurrenceId` (needed when image sources are overridden).
- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown
                             flags:(ENRMMd4cFlags *)flags
                             isGFM:(BOOL)isGFM
                         linkRegex:(ENRMLinkRegexConfig *)linkRegex
               inlineCodeLinkRegex:(ENRMLinkRegexConfig *)inlineCodeLinkRegex
                activeBlockSlotIds:(NSSet<NSString *> *)activeBlockSlotIds
                    annotateImages:(BOOL)annotateImages;

@end
