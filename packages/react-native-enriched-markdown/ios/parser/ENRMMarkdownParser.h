#import "MarkdownASTNode.h"
#import <Foundation/Foundation.h>

@interface ENRMMd4cFlags : NSObject <NSCopying>

@property (nonatomic, assign) BOOL underline;
@property (nonatomic, assign) BOOL latexMath;
@property (nonatomic, assign) BOOL superscript;
@property (nonatomic, assign) BOOL subscript;
@property (nonatomic, assign) BOOL highlight;
@property (nonatomic, assign) BOOL hardSoftBreaks;

+ (instancetype)defaultFlags;

@end

@interface ENRMMarkdownParser : NSObject

- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown;
- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown flags:(ENRMMd4cFlags *)flags;

@end
