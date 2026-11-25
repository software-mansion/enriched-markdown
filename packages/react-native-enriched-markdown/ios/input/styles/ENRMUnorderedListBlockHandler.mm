#import "ENRMUnorderedListBlockHandler.h"
#import "ENRMInputBlockType.h"

@implementation ENRMUnorderedListBlockHandler

- (ENRMInputBlockType)blockType
{
  return ENRMInputBlockTypeUnorderedListItem;
}

- (BOOL)continuesOnNewline
{
  return YES;
}

- (void)applyAttributesToParagraphStyle:(NSMutableParagraphStyle *)paragraphStyle
                             attributes:(NSMutableDictionary<NSAttributedStringKey, id> *)attributes
                             blockRange:(ENRMBlockRange *)blockRange
                                  style:(ENRMInputFormatterStyle *)style
{
  NSInteger depth = blockRange.level;
  if (depth < 0) {
    depth = 0;
  } else if (depth > kENRMMaxListDepth) {
    depth = kENRMMaxListDepth;
  }

  // Reserve a marker column per nesting level. Both the first (marker) line and
  // wrapped continuation lines align to the same text inset so wrapped text
  // hangs under the text, not under the bullet.
  CGFloat indent = (depth + 1) * kENRMListIndentPerDepth;
  paragraphStyle.firstLineHeadIndent = indent;
  paragraphStyle.headIndent = indent;
  paragraphStyle.paragraphSpacingBefore = style.listItemSpacing;
}

@end
