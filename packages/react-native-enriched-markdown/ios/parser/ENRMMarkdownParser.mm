#import "ENRMMarkdownParser.h"
#import "MarkdownASTNode.h"

extern MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags);

@implementation ENRMMd4cFlags

- (instancetype)init
{
  if (self = [super init]) {
    _underline = NO;
    _latexMath = YES;
    _superscript = NO;
    _subscript = NO;
    _highlight = NO;
    _hardSoftBreaks = NO;
  }
  return self;
}

+ (instancetype)defaultFlags
{
  return [[ENRMMd4cFlags alloc] init];
}

- (id)copyWithZone:(NSZone *)zone
{
  ENRMMd4cFlags *copy = [[ENRMMd4cFlags allocWithZone:zone] init];
  copy.underline = self.underline;
  copy.latexMath = self.latexMath;
  copy.superscript = self.superscript;
  copy.subscript = self.subscript;
  copy.highlight = self.highlight;
  copy.hardSoftBreaks = self.hardSoftBreaks;
  return copy;
}

@end

@implementation ENRMMarkdownParser

- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown
{
  return [self parseMarkdown:markdown flags:[ENRMMd4cFlags defaultFlags]];
}

- (MarkdownASTNode *)parseMarkdown:(NSString *)markdown flags:(ENRMMd4cFlags *)flags
{
  return parseMarkdownWithCppParser(markdown, flags);
}

@end
