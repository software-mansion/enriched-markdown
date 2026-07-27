#import "BlockquoteRenderer.h"
#import "BlockquoteBorder.h"
#import "FontUtils.h"
#import "LastElementUtils.h"
#import "ListItemRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
#import "RendererFactory.h"
#import "StyleConfig.h"

static NSString *const kNestedInfoDepthKey = @"depth";
static NSString *const kNestedInfoRangeKey = @"range";

@implementation BlockquoteRenderer

- (id)takeContextSnapshot:(RenderContext *)context
{
  return [context snapshotScope];
}

- (void)renderNodeContent:(MarkdownASTNode *)node
                     into:(NSMutableAttributedString *)output
                  context:(RenderContext *)context
{
  if (output.length > 0 && ![output.string hasSuffix:@"\n"]) {
    [output appendAttributedString:kNewlineAttributedString];
  }

  NSInteger currentDepth = context.blockquoteDepth;
  context.blockquoteDepth = currentDepth + 1;

  [context setBlockStyle:BlockTypeBlockquote
                    font:[_config blockquoteFont]
                   color:[_config blockquoteColor]
            headingLevel:0];

  NSUInteger start = output.length;
  [_rendererFactory renderChildrenOfNode:node into:output context:context];

  NSUInteger end = output.length;
  if (end <= start) {
    return;
  }

  [self applyStylingAndSpacing:output start:start end:end currentDepth:currentDepth context:context];
}

#pragma mark - Styling and Spacing

- (void)applyStylingAndSpacing:(NSMutableAttributedString *)output
                         start:(NSUInteger)start
                           end:(NSUInteger)end
                  currentDepth:(NSInteger)currentDepth
                       context:(RenderContext *)context
{
  NSUInteger contentStart = start;
  if (currentDepth == 0) {
    contentStart += applyBlockSpacingBefore(output, start, [_config blockquoteMarginTop]);
  }

  // Vertical padding: spacer lines inside the background area, applied at every
  // nesting level so nested quotes pad their own box (matching web CSS padding).
  // Mirrors CodeBlockRenderer's approach so measurement accounts for the padding.
  // Spacers carry BlockquoteSpacerAttributeName so ancestor quotes skip them
  // when stamping paragraph styles (their fixed height must survive).
  CGFloat padding = [_config blockquotePadding];
  NSUInteger topPadLength = 0;
  NSUInteger bottomPadLength = 0;
  if (padding > 0) {
    NSMutableParagraphStyle *topSpacerStyle = [context spacerStyleWithHeight:padding spacing:0];
    NSAttributedString *topSpacer = [[NSAttributedString alloc]
        initWithString:@"\n"
            attributes:@{NSParagraphStyleAttributeName : topSpacerStyle, BlockquoteSpacerAttributeName : @YES}];
    [output insertAttributedString:topSpacer atIndex:contentStart];
    topPadLength = 1;

    NSUInteger bottomSpacerLocation = output.length;
    [output appendAttributedString:kNewlineAttributedString];
    NSMutableParagraphStyle *bottomSpacerStyle = [context spacerStyleWithHeight:padding spacing:0];
    [output addAttributes:@{NSParagraphStyleAttributeName : bottomSpacerStyle, BlockquoteSpacerAttributeName : @YES}
                    range:NSMakeRange(bottomSpacerLocation, 1)];
    bottomPadLength = 1;
  }

  // The box range includes the padding spacers so the background covers them;
  // paragraph stamping is restricted to the inner range so the spacers keep
  // their fixed height instead of being clamped to the blockquote line height.
  NSRange blockquoteRange = NSMakeRange(contentStart, (end - start) + topPadLength + bottomPadLength);
  NSRange innerRange = NSMakeRange(contentStart + topPadLength, end - start);
  CGFloat levelSpacing = [_config blockquoteBorderWidth] + [_config blockquoteGapWidth];
  NSArray<NSDictionary *> *nestedInfo = [self collectNestedBlockquotes:output range:innerRange depth:currentDepth];

  // Apply base styling (indentation, depth, background, line height)
  [self applyBaseBlockquoteStyle:output
                        boxRange:blockquoteRange
                      innerRange:innerRange
                           depth:currentDepth
                    levelSpacing:levelSpacing
                 backgroundColor:[_config blockquoteBackgroundColor]
                      lineHeight:[_config blockquoteLineHeight]];

  // Re-apply nested blockquote styles to restore their correct indentation
  // (applyBaseBlockquoteStyle overwrites nested indents with the parent's indent)
  [self reapplyNestedStyles:output nestedInfo:nestedInfo levelSpacing:levelSpacing];

  if (currentDepth == 0) {
    applyBlockSpacingAfter(output, [_config blockquoteMarginBottom]);
  }
}

#pragma mark - Nested Blockquote Handling

- (NSArray<NSDictionary *> *)collectNestedBlockquotes:(NSMutableAttributedString *)output
                                                range:(NSRange)blockquoteRange
                                                depth:(NSInteger)currentDepth
{
  NSMutableArray<NSDictionary *> *nestedInfo = [NSMutableArray array];

  [output
      enumerateAttribute:BlockquoteDepthAttributeName
                 inRange:blockquoteRange
                 options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
              usingBlock:^(id value, NSRange range, BOOL *stop) {
                NSInteger depth = [value integerValue];
                if (value && depth > currentDepth) {
                  [nestedInfo
                      addObject:@{kNestedInfoDepthKey : value, kNestedInfoRangeKey : [NSValue valueWithRange:range]}];
                }
              }];

  return nestedInfo;
}

- (void)applyBaseBlockquoteStyle:(NSMutableAttributedString *)output
                        boxRange:(NSRange)boxRange
                      innerRange:(NSRange)innerRange
                           depth:(NSInteger)currentDepth
                    levelSpacing:(CGFloat)levelSpacing
                 backgroundColor:(RCTUIColor *)backgroundColor
                      lineHeight:(CGFloat)lineHeight
{
  CGFloat totalIndent = blockquoteIndentForDepth(currentDepth + 1, levelSpacing);
  CGFloat padding = [_config blockquotePadding];

  // Depth and background cover the whole box (incl. padding spacers) so the
  // border and background render behind list content and the padding rows.
  NSMutableDictionary *depthAttributes =
      [NSMutableDictionary dictionaryWithObjectsAndKeys:@(currentDepth), BlockquoteDepthAttributeName, nil];
  if (backgroundColor) {
    depthAttributes[BlockquoteBackgroundColorAttributeName] = backgroundColor;
  }
  [output addAttributes:depthAttributes range:boxRange];

  // List items bake the blockquote indent into their own paragraph style; only non-list content is stamped here.
  [self enumerateNonListRangesIn:output
                           range:innerRange
                      usingBlock:^(NSRange nonListRange) {
                        NSMutableParagraphStyle *paragraphStyle =
                            getOrCreateParagraphStyle(output, nonListRange.location);
                        paragraphStyle.firstLineHeadIndent = totalIndent;
                        paragraphStyle.headIndent = totalIndent;
                        if (padding > 0) {
                          paragraphStyle.tailIndent = -padding;
                        }
                        [output addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:nonListRange];
                        applyLineHeight(output, nonListRange, lineHeight);
                      }];
}

- (void)reapplyNestedStyles:(NSMutableAttributedString *)output
                 nestedInfo:(NSArray<NSDictionary *> *)nestedInfo
               levelSpacing:(CGFloat)levelSpacing
{
  // Re-apply indentation to nested blockquotes since applyBaseBlockquoteStyle
  // overwrote them with the parent's indentation
  CGFloat padding = [_config blockquotePadding];
  for (NSDictionary *info in nestedInfo) {
    NSRange nestedRange = [info[kNestedInfoRangeKey] rangeValue];
    NSInteger nestedDepth = [info[kNestedInfoDepthKey] integerValue];
    CGFloat indent = blockquoteIndentForDepth(nestedDepth + 1, levelSpacing);

    [output addAttribute:BlockquoteDepthAttributeName value:info[kNestedInfoDepthKey] range:nestedRange];

    [self enumerateNonListRangesIn:output
                             range:nestedRange
                        usingBlock:^(NSRange nonListRange) {
                          NSMutableParagraphStyle *style = getOrCreateParagraphStyle(output, nonListRange.location);
                          style.firstLineHeadIndent = indent;
                          style.headIndent = indent;
                          style.tailIndent = padding > 0 ? -padding : 0;
                          [output addAttribute:NSParagraphStyleAttributeName value:style range:nonListRange];
                        }];
  }
}

- (void)enumerateNonListRangesIn:(NSMutableAttributedString *)output
                           range:(NSRange)range
                      usingBlock:(void (^)(NSRange nonListRange))block
{
  // List items — and code blocks nested inside them (which carry a list-derived
  // indent instead of ListDepthAttribute) — already bake the correct indent in.
  NSMutableArray<NSValue *> *listRanges = [NSMutableArray array];
  void (^collectRanges)(NSString *) = ^(NSString *attribute) {
    [output enumerateAttribute:attribute
                       inRange:range
                       options:0
                    usingBlock:^(id value, NSRange subRange, BOOL *stop) {
                      if (value) {
                        [listRanges addObject:[NSValue valueWithRange:subRange]];
                      }
                    }];
  };
  collectRanges(ListDepthAttribute);
  collectRanges(CodeBlockIndentAttributeName);
  collectRanges(BlockquoteSpacerAttributeName);
  [listRanges sortUsingComparator:^NSComparisonResult(NSValue *a, NSValue *b) {
    NSUInteger la = [a rangeValue].location;
    NSUInteger lb = [b rangeValue].location;
    return la < lb ? NSOrderedAscending : (la > lb ? NSOrderedDescending : NSOrderedSame);
  }];

  NSUInteger pos = range.location;
  const NSUInteger end = NSMaxRange(range);
  for (NSValue *val in listRanges) {
    NSRange listRange = [val rangeValue];
    if (pos < listRange.location) {
      block(NSMakeRange(pos, listRange.location - pos));
    }
    pos = MAX(pos, NSMaxRange(listRange));
  }
  if (pos < end) {
    block(NSMakeRange(pos, end - pos));
  }
}

@end
