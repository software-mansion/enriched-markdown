#import "ENRMInputListMarkerDrawer.h"
#import "ENRMInputBlockType.h"
#import "ParagraphStyleUtils.h"

static UIFont *ENRMFallbackFont(void)
{
  return [UIFont systemFontOfSize:16];
}

static UIColor *ENRMFallbackColor(void)
{
  return [UIColor labelColor];
}

static CGFloat ENRMTrailingMarkerX(CGPoint origin, NSTextContainer *container, CGFloat leadingOffset)
{
  return origin.x + container.size.width - leadingOffset;
}

#pragma mark -

@implementation ENRMInputListMarkerDrawer {
  NSMutableSet<NSNumber *> *_drawnParagraphLocations;
}

- (instancetype)init
{
  if (self = [super init]) {
    _emptyBulletDepth = -1;
    _drawnParagraphLocations = [NSMutableSet set];
  }
  return self;
}

#pragma mark - Primitive Drawing

- (void)drawBulletAtX:(CGFloat)markerX
              centerY:(CGFloat)centerY
                depth:(NSInteger)depth
                 font:(UIFont *)font
                color:(UIColor *)color
{
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  if (!ctx || isnan(markerX) || isnan(centerY)) {
    return;
  }

  CGFloat size = MAX(4.0, font.pointSize * 0.30);
  CGRect bulletRect = CGRectMake(markerX - size / 2.0, centerY - size / 2.0, size, size);

  CGContextSaveGState(ctx);
  NSInteger style = ((depth % 3) + 3) % 3;
  switch (style) {
    case 0:
      [color setFill];
      CGContextFillEllipseInRect(ctx, bulletRect);
      break;
    case 1: {
      CGFloat lineWidth = MAX(1.0, size * 0.15);
      [color setStroke];
      CGContextSetLineWidth(ctx, lineWidth);
      CGContextStrokeEllipseInRect(ctx, CGRectInset(bulletRect, lineWidth / 2.0, lineWidth / 2.0));
      break;
    }
    default:
      [color setFill];
      CGContextFillRect(ctx, bulletRect);
      break;
  }
  CGContextRestoreGState(ctx);
}

- (void)drawOrderedMarkerEndingAtX:(CGFloat)markerRight
                         baselineY:(CGFloat)baselineY
                           ordinal:(NSInteger)ordinal
                              font:(UIFont *)font
                             color:(UIColor *)color
{
  NSString *label = [NSString stringWithFormat:@"%ld.", (long)MAX(ordinal, (NSInteger)1)];
  NSDictionary *attrs = @{NSFontAttributeName : font, NSForegroundColorAttributeName : color};
  CGSize labelSize = [label sizeWithAttributes:attrs];
  [label drawAtPoint:CGPointMake(markerRight - labelSize.width, baselineY - font.ascender) withAttributes:attrs];
}

- (void)drawOrderedMarkerStartingAtX:(CGFloat)markerLeft
                           baselineY:(CGFloat)baselineY
                             ordinal:(NSInteger)ordinal
                                font:(UIFont *)font
                               color:(UIColor *)color
{
  NSString *label = [NSString stringWithFormat:@".%ld", (long)MAX(ordinal, (NSInteger)1)];
  NSDictionary *attrs = @{NSFontAttributeName : font, NSForegroundColorAttributeName : color};
  [label drawAtPoint:CGPointMake(markerLeft, baselineY - font.ascender) withAttributes:attrs];
}

#pragma mark - Composite Marker

- (void)drawListMarkerOrdered:(BOOL)isOrdered
                        depth:(NSInteger)depth
                      ordinal:(NSInteger)ordinal
                          rtl:(BOOL)isRTL
                    baselineY:(CGFloat)baselineY
                       origin:(CGPoint)origin
                     usedRect:(CGRect)usedRect
                    container:(NSTextContainer *)container
                         font:(UIFont *)font
                        color:(UIColor *)color
{
  CGFloat leadingOffset = container.lineFragmentPadding + (depth + 1) * kENRMListIndentPerDepth;

  if (isOrdered) {
    if (isRTL) {
      CGFloat anchorX = ENRMTrailingMarkerX(origin, container, leadingOffset) + kENRMListBulletGap / 2.0;
      [self drawOrderedMarkerStartingAtX:anchorX baselineY:baselineY ordinal:ordinal font:font color:color];
    } else {
      CGFloat anchorX = origin.x + usedRect.origin.x - kENRMListBulletGap / 2.0;
      [self drawOrderedMarkerEndingAtX:anchorX baselineY:baselineY ordinal:ordinal font:font color:color];
    }
    return;
  }

  CGFloat markerX = isRTL ? ENRMTrailingMarkerX(origin, container, leadingOffset) + kENRMListBulletGap
                          : origin.x + usedRect.origin.x - kENRMListBulletGap;
  CGFloat centerY = baselineY - (font.xHeight + font.capHeight) / 4.0;
  [self drawBulletAtX:markerX centerY:centerY depth:depth font:font color:color];
}

#pragma mark - Attribute Resolution

- (BOOL)readListAttributesAtIndex:(NSUInteger)charIndex
                          storage:(NSTextStorage *)storage
                        paraStart:(NSUInteger)paraStart
                        isOrdered:(out BOOL *)outOrdered
                            depth:(out NSInteger *)outDepth
                          ordinal:(out NSInteger *)outOrdinal
{
  if (charIndex >= storage.length) {
    return NO;
  }

  NSNumber *type = [storage attribute:ENRMBlockTypeAttributeName atIndex:charIndex effectiveRange:NULL];
  if (!type || !ENRMBlockTypeIsListItem((ENRMInputBlockType)type.integerValue) || charIndex != paraStart) {
    return NO;
  }

  *outOrdered = (type.integerValue == ENRMInputBlockTypeOrderedListItem);

  NSNumber *depthValue = [storage attribute:ENRMBlockLevelAttributeName atIndex:charIndex effectiveRange:NULL];
  *outDepth = depthValue ? depthValue.integerValue : 0;

  NSNumber *ordinalValue = [storage attribute:ENRMBlockOrdinalAttributeName atIndex:charIndex effectiveRange:NULL];
  *outOrdinal = ordinalValue ? ordinalValue.integerValue : 1;

  return YES;
}

- (void)resolveMarkerFont:(out UIFont **)outFont
                    color:(out UIColor **)outColor
                  atIndex:(NSUInteger)charIndex
                  storage:(NSTextStorage *)storage
          isEmptyListLine:(BOOL)isEmptyListLine
{
  UIFont *font = nil;
  UIColor *color = nil;

  if (isEmptyListLine) {
    font = self.emptyBulletFont;
    color = self.emptyBulletColor;
  }
  if (!font && charIndex < storage.length) {
    font = [storage attribute:NSFontAttributeName atIndex:charIndex effectiveRange:NULL];
  }
  if (!color && charIndex < storage.length) {
    color = [storage attribute:NSForegroundColorAttributeName atIndex:charIndex effectiveRange:NULL];
  }

  *outFont = font ?: ENRMFallbackFont();
  *outColor = color ?: ENRMFallbackColor();
}

#pragma mark - Fragment Processing

- (void)processLineFragmentRect:(CGRect)rect
                       usedRect:(CGRect)usedRect
                      container:(NSTextContainer *)container
                     glyphRange:(NSRange)glyphRange
                         origin:(CGPoint)origin
                  layoutManager:(NSLayoutManager *)layoutManager
                        storage:(NSTextStorage *)storage
                         string:(NSString *)string
{
  NSRange charRange = [layoutManager characterRangeForGlyphRange:glyphRange actualGlyphRange:NULL];
  if (charRange.location == NSNotFound) {
    return;
  }

  NSRange paraRange = (charRange.location < string.length) ? [string paragraphRangeForRange:charRange]
                                                           : NSMakeRange(charRange.location, 0);

  if ([_drawnParagraphLocations containsObject:@(paraRange.location)]) {
    return;
  }

  BOOL isOrdered = NO;
  NSInteger depth = 0;
  NSInteger ordinal = 1;
  BOOL isAttributedListLine = [self readListAttributesAtIndex:charRange.location
                                                      storage:storage
                                                    paraStart:paraRange.location
                                                    isOrdered:&isOrdered
                                                        depth:&depth
                                                      ordinal:&ordinal];

  BOOL isEmptyListLine =
      !isAttributedListLine && self.emptyBulletDepth >= 0 && charRange.location == self.emptyBulletLocation;
  if (isEmptyListLine) {
    depth = self.emptyBulletDepth;
    isOrdered = self.emptyBulletOrdered;
    ordinal = self.emptyBulletOrdinal;
  }

  if (!isAttributedListLine && !isEmptyListLine) {
    return;
  }
  [_drawnParagraphLocations addObject:@(paraRange.location)];

  UIFont *font;
  UIColor *color;
  [self resolveMarkerFont:&font
                    color:&color
                  atIndex:charRange.location
                  storage:storage
          isEmptyListLine:isEmptyListLine];

  CGFloat baselineOffset = isEmptyListLine ? self.listItemSpacing + font.ascender
                                           : [layoutManager locationForGlyphAtIndex:glyphRange.location].y;
  CGFloat baselineY = origin.y + rect.origin.y + baselineOffset;

  BOOL isRTL = isEmptyListLine ? self.emptyBulletRTL
                               : ENRMParagraphIsRTL([storage attribute:NSParagraphStyleAttributeName
                                                               atIndex:charRange.location
                                                        effectiveRange:NULL]);

  [self drawListMarkerOrdered:isOrdered
                        depth:depth
                      ordinal:ordinal
                          rtl:isRTL
                    baselineY:baselineY
                       origin:origin
                     usedRect:usedRect
                    container:container
                         font:font
                        color:color];
}

#pragma mark - ENRMInputDecorationDrawer

- (void)drawDecorationsForGlyphRange:(NSRange)glyphRange
                       layoutManager:(NSLayoutManager *)layoutManager
                             atPoint:(CGPoint)origin
{
  NSTextStorage *storage = layoutManager.textStorage;
  NSString *string = storage.string;
  [_drawnParagraphLocations removeAllObjects];

  [layoutManager enumerateLineFragmentsForGlyphRange:glyphRange
                                          usingBlock:^(CGRect rect, CGRect usedRect, NSTextContainer *container,
                                                       NSRange fragmentGlyphRange, __unused BOOL *stop) {
                                            [self processLineFragmentRect:rect
                                                                 usedRect:usedRect
                                                                container:container
                                                               glyphRange:fragmentGlyphRange
                                                                   origin:origin
                                                            layoutManager:layoutManager
                                                                  storage:storage
                                                                   string:string];
                                          }];

  // Trailing empty line has no glyph fragment — draw via extra line fragment.
  if (self.emptyBulletDepth >= 0 && self.emptyBulletLocation >= storage.length &&
      layoutManager.extraLineFragmentTextContainer != nil) {
    UIFont *font = self.emptyBulletFont ?: ENRMFallbackFont();
    UIColor *color = self.emptyBulletColor ?: ENRMFallbackColor();
    CGRect used = layoutManager.extraLineFragmentUsedRect;
    CGFloat baselineY = origin.y + used.origin.y + font.ascender;
    [self drawListMarkerOrdered:self.emptyBulletOrdered
                          depth:self.emptyBulletDepth
                        ordinal:self.emptyBulletOrdinal
                            rtl:self.emptyBulletRTL
                      baselineY:baselineY
                         origin:origin
                       usedRect:used
                      container:layoutManager.extraLineFragmentTextContainer
                           font:font
                          color:color];
  }
}

- (void)drawEmptyEditorDecorationsWithInset:(UIEdgeInsets)inset layoutManager:(NSLayoutManager *)layoutManager
{
  if (self.emptyBulletDepth < 0) {
    return;
  }

  UIFont *font = self.emptyBulletFont ?: ENRMFallbackFont();
  UIColor *color = self.emptyBulletColor ?: ENRMFallbackColor();
  NSTextContainer *container = layoutManager.textContainers.firstObject;
  BOOL isRTL = self.emptyBulletRTL && container != nil;

  CGFloat headIndent = (self.emptyBulletDepth + 1) * kENRMListIndentPerDepth;
  CGFloat padding = container ? container.lineFragmentPadding : 0;
  CGRect syntheticUsedRect = CGRectMake(padding + headIndent, 0, 0, 0);
  CGPoint syntheticOrigin = CGPointMake(inset.left, 0);
  NSTextContainer *drawContainer = container ?: [[NSTextContainer alloc] initWithSize:CGSizeMake(0, CGFLOAT_MAX)];

  CGFloat baselineY = inset.top + font.ascender;

  [self drawListMarkerOrdered:self.emptyBulletOrdered
                        depth:self.emptyBulletDepth
                      ordinal:self.emptyBulletOrdinal
                          rtl:isRTL
                    baselineY:baselineY
                       origin:syntheticOrigin
                     usedRect:syntheticUsedRect
                    container:drawContainer
                         font:font
                        color:color];
}

@end
