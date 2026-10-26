#import "BaseRenderer.h"
#import "ENRMWordMajority.h"
#import "LastElementUtils.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

// writingDirection="word-majority": give the block's paragraphs the direction
// ENRMWordMajorityAST resolved for it. Code blocks always stay LTR.
static void ENRMApplyProseDirection(MarkdownASTNode *node, NSMutableAttributedString *output, NSUInteger start)
{
  NSString *direction = node.attributes[ENRMProseDirectionKey];
  if (!direction || output.length <= start)
    return;
  switch (node.type) {
    case MarkdownNodeTypeParagraph:
    case MarkdownNodeTypeHeading:
    case MarkdownNodeTypeListItem: // ListItemRenderer replaces its paragraphs' styles
    case MarkdownNodeTypeCodeBlock:
      break;
    default:
      return;
  }
  NSWritingDirection writingDirection = node.type != MarkdownNodeTypeCodeBlock && [direction isEqualToString:@"rtl"]
                                            ? NSWritingDirectionRightToLeft
                                            : NSWritingDirectionLeftToRight;
  NSRange range = NSMakeRange(start, output.length - start);
  [output enumerateAttribute:NSParagraphStyleAttributeName
                     inRange:range
                     options:0
                  usingBlock:^(NSParagraphStyle *style, NSRange run, BOOL *stop) {
                    // A code block nested in an RTL list item keeps its own LTR direction.
                    if (style.baseWritingDirection == writingDirection ||
                        (node.type != MarkdownNodeTypeCodeBlock && [output attribute:CodeBlockAttributeName
                                                                              atIndex:run.location
                                                                       effectiveRange:NULL]))
                      return;
                    NSMutableParagraphStyle *updated = style ? [style mutableCopy] : [NSMutableParagraphStyle new];
                    updated.baseWritingDirection = writingDirection;
                    [output addAttribute:NSParagraphStyleAttributeName value:updated range:run];
                  }];
}

@implementation BaseRenderer

- (instancetype)initWithRendererFactory:(id)rendererFactory config:(id)config
{
  if (self = [super init]) {
    _rendererFactory = rendererFactory;
    _config = (StyleConfig *)config;
  }
  return self;
}

- (void)renderNode:(MarkdownASTNode *)node into:(NSMutableAttributedString *)output context:(RenderContext *)context
{
  NSUInteger start = output.length;
  id snapshot = [self takeContextSnapshot:context];
  @try {
    [self renderNodeContent:node into:output context:context];
  } @finally {
    [self restoreContextSnapshot:snapshot context:context];
  }
  ENRMApplyProseDirection(node, output, start);
}

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{
  [self doesNotRecognizeSelector:_cmd];
}

- (id)takeContextSnapshot:(RenderContext *)context
{
  return nil;
}

- (void)restoreContextSnapshot:(id)snapshot context:(RenderContext *)context
{
  if (snapshot) {
    [context restoreScope:snapshot];
  }
}

@end
