#import "UnderlineRenderer.h"
#import "ENRMTextLinkAttributes.h"
#import "MarkdownASTNode.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

@implementation UnderlineRenderer

#pragma mark - Rendering

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{
  NSUInteger start = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  [output addAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlineStyleSingle) range:range];
  [output addAttribute:ENRMRecognizedLinkOriginalUnderlineAttributeName value:@(NSUnderlineStyleSingle) range:range];

  RCTUIColor *underlineColor = [_config underlineColor];

  [output addAttribute:NSUnderlineColorAttributeName value:underlineColor range:range];
}

@end
