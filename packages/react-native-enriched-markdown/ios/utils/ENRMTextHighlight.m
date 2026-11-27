#import "ENRMTextHighlight.h"

@implementation ENRMTextHighlight

- (instancetype)initWithRange:(NSRange)range
                        color:(RCTUIColor *)color
                 borderRadius:(CGFloat)borderRadius
                      padding:(CGFloat)padding
{
  self = [super init];
  if (self) {
    _range = range;
    _color = color;
    _borderRadius = MAX(0, borderRadius);
    _padding = padding;
  }
  return self;
}

- (instancetype)highlightWithRange:(NSRange)range
{
  return [[ENRMTextHighlight alloc] initWithRange:range color:_color borderRadius:_borderRadius padding:_padding];
}

- (BOOL)isEqual:(id)object
{
  if (self == object) {
    return YES;
  }
  if (![object isKindOfClass:[ENRMTextHighlight class]]) {
    return NO;
  }
  ENRMTextHighlight *other = object;
  return NSEqualRanges(_range, other.range) && [_color isEqual:other.color] && _borderRadius == other.borderRadius &&
         _padding == other.padding;
}

- (NSUInteger)hash
{
  return _range.location ^ (_range.length << 16) ^ _color.hash;
}

@end

RCTUIColor *ENRMColorFromARGB(int32_t argb)
{
  uint32_t value = (uint32_t)argb;
  return [RCTUIColor colorWithRed:((value >> 16) & 0xFF) / 255.0
                            green:((value >> 8) & 0xFF) / 255.0
                             blue:(value & 0xFF) / 255.0
                            alpha:((value >> 24) & 0xFF) / 255.0];
}

void ENRMEnumerateHighlightLineRects(NSLayoutManager *layoutManager, NSRange range, NSRange glyphRange,
                                     void (^block)(CGRect rect))
{
  NSUInteger length = layoutManager.textStorage.length;
  if (range.location == NSNotFound || range.length == 0 || NSMaxRange(range) > length) {
    return;
  }
  NSRange glyphs = [layoutManager glyphRangeForCharacterRange:range actualCharacterRange:NULL];
  NSRange visible = NSIntersectionRange(glyphs, glyphRange);
  if (visible.length == 0) {
    return;
  }
  [layoutManager
      enumerateLineFragmentsForGlyphRange:visible
                               usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                            NSRange lineGlyphs, BOOL *stop) {
                                 NSRange part = NSIntersectionRange(lineGlyphs, visible);
                                 if (part.length == 0) {
                                   return;
                                 }
                                 // One rect per visual run: in mixed-direction text a single bounding rect
                                 // would also cover the unselected glyphs between runs. Enclosing rects can
                                 // reach the line's edge, so each is trimmed to the glyphs' bounds.
                                 CGRect bounds = [layoutManager boundingRectForGlyphRange:part
                                                                          inTextContainer:container];
                                 // Paragraph spacing below a paragraph's last line stays out of the box.
                                 bounds.size.height =
                                     MAX(0, MIN(CGRectGetMaxY(bounds), CGRectGetMaxY(usedRect)) - bounds.origin.y);
                                 [layoutManager
                                     enumerateEnclosingRectsForGlyphRange:part
                                                 withinSelectedGlyphRange:NSMakeRange(NSNotFound, 0)
                                                          inTextContainer:container
                                                               usingBlock:^(CGRect enclosing, BOOL *stopRects) {
                                                                 CGRect box = CGRectIntersection(enclosing, bounds);
                                                                 if (!CGRectIsNull(box) && box.size.width > 0 &&
                                                                     box.size.height > 0) {
                                                                   block(box);
                                                                 }
                                                               }];
                               }];
}

static CGRect ENRMPaddedRect(CGRect rect, CGFloat padding)
{
  return CGRectInset(rect, -padding, -padding);
}

void ENRMDrawTextHighlights(NSArray<ENRMTextHighlight *> *highlights, NSLayoutManager *layoutManager,
                            NSRange glyphsToShow, CGPoint origin)
{
  for (ENRMTextHighlight *highlight in highlights) {
    [highlight.color setFill];
    CGFloat padding = highlight.padding;
    CGFloat radius = highlight.borderRadius;
    ENRMEnumerateHighlightLineRects(layoutManager, highlight.range, glyphsToShow, ^(CGRect rect) {
      CGRect box = CGRectOffset(ENRMPaddedRect(rect, padding), origin.x, origin.y);
      [UIBezierPathWithRoundedRect(box, MIN(radius, MIN(box.size.width, box.size.height) / 2)) fill];
    });
  }
}

CGRect ENRMTextHighlightBounds(ENRMTextHighlight *highlight, NSLayoutManager *layoutManager)
{
  __block CGRect bounds = CGRectNull;
  CGFloat padding = highlight.padding;
  ENRMEnumerateHighlightLineRects(layoutManager, highlight.range, NSMakeRange(0, layoutManager.numberOfGlyphs),
                                  ^(CGRect rect) { bounds = CGRectUnion(bounds, ENRMPaddedRect(rect, padding)); });
  return bounds;
}
