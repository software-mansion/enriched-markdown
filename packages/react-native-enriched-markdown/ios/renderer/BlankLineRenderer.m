#import "BlankLineRenderer.h"
#import "MarkdownASTNode.h"
#import "StyleConfig.h"

#pragma mark - Renderer Implementation

// Renders a run of consecutive blank lines emitted by the parser when the
// preserveBlankLines flag is enabled. Each blank line in the source is drawn as
// one empty line, so the rendered text keeps the exact line count that was typed
// (e.g. in EnrichedMarkdownTextInput). Any extra vertical spacing comes from the
// surrounding paragraph style and is left to the caller to configure via
// markdownStyle.
@implementation BlankLineRenderer

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{
  NSInteger count = [node.attributes[@"count"] integerValue];
  if (count <= 0) {
    return;
  }

  [self ensureStartingNewline:output];

  NSDictionary *attributes = @{
    NSFontAttributeName : _config.paragraphFont,
    NSParagraphStyleAttributeName : [NSParagraphStyle defaultParagraphStyle]
  };

  NSMutableString *blanks = [NSMutableString stringWithCapacity:(NSUInteger)count];
  for (NSInteger i = 0; i < count; i++) {
    [blanks appendString:@"\n"];
  }

  [output appendAttributedString:[[NSAttributedString alloc] initWithString:blanks attributes:attributes]];
}

#pragma mark - Private Utilities

- (void)ensureStartingNewline:(NSMutableAttributedString *)output
{
  if (output.length > 0 && ![output.string hasSuffix:@"\n"]) {
    [output appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n"]];
  }
}

@end
