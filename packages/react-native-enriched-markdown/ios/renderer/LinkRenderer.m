#import "LinkRenderer.h"
#import "ENRMLinkPillAttachment.h"
#import "FontUtils.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"
#import <React/RCTFont.h>

#if !TARGET_OS_OSX
static BOOL ENRMRangeHasAttachment(NSAttributedString *text, NSRange range)
{
  __block BOOL found = NO;
  [text enumerateAttribute:NSAttachmentAttributeName
                   inRange:range
                   options:0
                usingBlock:^(id value, NSRange subrange, BOOL *stop) {
                  if (value) {
                    found = YES;
                    *stop = YES;
                  }
                }];
  return found;
}
#endif

@implementation LinkRenderer

#pragma mark - Rendering

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{
  NSUInteger start = output.length;

  // 1. Render children first to establish base attributes
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSRange range = NSMakeRange(start, output.length - start);
  if (range.length == 0)
    return;

  // 2. Extract configuration
  NSString *url = node.attributes[@"url"] ?: @"";
  LinkVariantConfig *variant = [_config effectiveLinkVariantForURL:url];

  RCTUIColor *linkColor = variant.color ?: [_config linkColor];
  BOOL linkUnderline = variant ? variant.underline : [_config linkUnderline];
  NSString *linkFontFamily = variant.fontFamily.length > 0 ? variant.fontFamily : [_config linkFontFamily];
  RCTUIColor *backgroundColor = variant ? variant.backgroundColor : [_config linkBackgroundColor];

  NSNumber *underlineStyle = @(linkUnderline ? NSUnderlineStyleSingle : NSUnderlineStyleNone);

  // 3. Apply core link functionality (non-destructive)
  [output addAttribute:NSLinkAttributeName value:url range:range];

  // 4. Optimize visual attributes via enumeration to avoid redundant updates
  [output enumerateAttributesInRange:range
                             options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                          usingBlock:^(NSDictionary<NSAttributedStringKey, id> *attrs, NSRange subrange, BOOL *stop) {
                            NSMutableDictionary *newAttributes = [NSMutableDictionary dictionary];

                            // Only apply link color if the subrange isn't already colored by the link style
                            if (linkColor && ![attrs[NSForegroundColorAttributeName] isEqual:linkColor]) {
                              newAttributes[NSForegroundColorAttributeName] = linkColor;
                              newAttributes[NSUnderlineColorAttributeName] = linkColor;
                            }

                            // Only update underline style if it differs from the config
                            if (![attrs[NSUnderlineStyleAttributeName] isEqual:underlineStyle]) {
                              newAttributes[NSUnderlineStyleAttributeName] = underlineStyle;
                            }

                            if (linkFontFamily.length > 0) {
                              UIFont *currentFont = attrs[NSFontAttributeName];
                              if (currentFont) {
                                UIFont *linkFont = [RCTFont updateFont:currentFont
                                                            withFamily:linkFontFamily
                                                                  size:nil
                                                                weight:nil
                                                                 style:nil
                                                               variant:nil
                                                       scaleMultiplier:1.0];
                                if (linkFont && ![currentFont isEqual:linkFont]) {
                                  newAttributes[NSFontAttributeName] = linkFont;
                                }
                              }
                            }

                            if (newAttributes.count > 0) {
                              [output addAttributes:newAttributes range:subrange];
                            }
                          }];

#if !TARGET_OS_OSX
  BOOL willBePill = variant.pill && !ENRMRangeHasAttachment(output, range);
#else
  BOOL willBePill = NO;
#endif
  if (backgroundColor && !willBePill)
    [output addAttribute:NSBackgroundColorAttributeName value:backgroundColor range:range];

#if !TARGET_OS_OSX
  if (willBePill) {
    UIFont *font = [output attribute:NSFontAttributeName atIndex:range.location effectiveRange:NULL];
    ENRMLinkPillAttachment *pill =
        [[ENRMLinkPillAttachment alloc] initWithLinkText:[output.string substringWithRange:range]
                                                 variant:variant
                                                    font:font ?: [context getBlockStyle].cachedFont];
    // Children may already have an inline-code background. Pills draw their own.
    [output removeAttribute:NSBackgroundColorAttributeName range:range];
    [output addAttribute:NSAttachmentAttributeName value:pill range:range];
  }
#endif
  [context registerLinkRange:range url:url];
}

@end