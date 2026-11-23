#import "ENRMImageFailurePlaceholder.h"

static const CGFloat kChipMaxWidth = 200.0;
static const CGFloat kChipPaddingRatio = 0.2;
static const CGFloat kChipGlyphRatio = 0.7;
static const CGFloat kChipFontRatio = 0.6;
static const CGFloat kChipCornerRatio = 0.2;
static const CGFloat kBlockGlyphMaxSize = 32.0;
static const CGFloat kBlockGlyphRatio = 0.4;
static const CGFloat kBlockTextPadding = 8.0;
static const CGFloat kBlockGap = 6.0;
static const CGFloat kFillAlpha = 0.08;
static const CGFloat kGlyphAlpha = 0.45;
static const CGFloat kTextAlpha = 0.7;

@implementation ENRMImageFailurePlaceholder {
  NSString *_altText;
  RCTUIColor *_color;
  CGFloat _fontSize;
  CGFloat _borderRadius;
}

- (instancetype)initWithAltText:(NSString *)altText
                          color:(RCTUIColor *)color
                       fontSize:(CGFloat)fontSize
                   borderRadius:(CGFloat)borderRadius
{
  self = [super init];
  if (self) {
    _altText = [altText copy];
    _color = color;
    _fontSize = fontSize;
    _borderRadius = borderRadius;
  }
  return self;
}

- (NSDictionary<NSAttributedStringKey, id> *)textAttributesWithFontSize:(CGFloat)fontSize
                                                              alignment:(NSTextAlignment)alignment
{
  NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
  paragraph.alignment = alignment;
  paragraph.lineBreakMode = NSLineBreakByTruncatingTail;
  return @{
    NSFontAttributeName : [UIFont systemFontOfSize:fontSize],
    NSForegroundColorAttributeName : [_color colorWithAlphaComponent:kTextAlpha],
    NSParagraphStyleAttributeName : paragraph,
  };
}

- (CGFloat)chipFontSizeForHeight:(CGFloat)height
{
  return MIN(_fontSize, height * kChipFontRatio);
}

- (CGFloat)chipWidthForHeight:(CGFloat)height maxWidth:(CGFloat)maxWidth
{
  if (_altText.length == 0) {
    return height;
  }
  NSDictionary *attributes = [self textAttributesWithFontSize:[self chipFontSizeForHeight:height]
                                                    alignment:NSTextAlignmentLeft];
  CGFloat padding = height * kChipPaddingRatio;
  CGFloat textWidth = ceil([_altText sizeWithAttributes:attributes].width);
  CGFloat width = padding + height * kChipGlyphRatio + padding + textWidth + padding;
  CGFloat cap = maxWidth > 0 ? MIN(kChipMaxWidth, maxWidth) : kChipMaxWidth;
  return MAX(height, MIN(width, cap));
}

- (RCTUIImage *)imageForSize:(CGSize)size isInline:(BOOL)isInline
{
  return [ImageRendererForSize(size) imageWithActions:^(RCTUIGraphicsImageRendererContext *context) {
    CGRect box = CGRectMake(0, 0, size.width, size.height);
    CGFloat radius = isInline ? size.height * kChipCornerRatio : self->_borderRadius;
    [[self->_color colorWithAlphaComponent:kFillAlpha] setFill];
    [UIBezierPathWithRoundedRect(box, radius) fill];

    if (isInline) {
      [self drawChipContentInBox:box];
    } else {
      [self drawBlockContentInBox:box];
    }
  }];
}

- (void)drawChipContentInBox:(CGRect)box
{
  CGFloat height = box.size.height;
  CGFloat glyphSize = height * kChipGlyphRatio;
  CGFloat padding = height * kChipPaddingRatio;

  if (_altText.length == 0) {
    [self drawGlyphInRect:CGRectMake((box.size.width - glyphSize) / 2.0, (height - glyphSize) / 2.0, glyphSize,
                                     glyphSize)];
    return;
  }

  [self drawGlyphInRect:CGRectMake(padding, (height - glyphSize) / 2.0, glyphSize, glyphSize)];

  CGFloat fontSize = [self chipFontSizeForHeight:height];
  NSDictionary *attributes = [self textAttributesWithFontSize:fontSize alignment:NSTextAlignmentLeft];
  CGFloat textHeight = ceil([_altText sizeWithAttributes:attributes].height);
  CGFloat textX = padding + glyphSize + padding;
  [_altText drawInRect:CGRectMake(textX, (height - textHeight) / 2.0, box.size.width - textX - padding, textHeight)
        withAttributes:attributes];
}

- (void)drawBlockContentInBox:(CGRect)box
{
  CGFloat glyphSize = MIN(kBlockGlyphMaxSize, box.size.height * kBlockGlyphRatio);
  NSDictionary *attributes = [self textAttributesWithFontSize:_fontSize alignment:NSTextAlignmentCenter];
  CGFloat textHeight = _altText.length > 0 ? ceil([_altText sizeWithAttributes:attributes].height) : 0;
  CGFloat gap = textHeight > 0 ? kBlockGap : 0;

  // A box too short for both keeps the alt text: it says what is missing.
  BOOL showsGlyph = textHeight == 0 || glyphSize + gap + textHeight <= box.size.height;
  CGFloat contentHeight = showsGlyph ? glyphSize + gap + textHeight : textHeight;
  CGFloat top = (box.size.height - contentHeight) / 2.0;

  if (showsGlyph) {
    [self drawGlyphInRect:CGRectMake((box.size.width - glyphSize) / 2.0, top, glyphSize, glyphSize)];
    top += glyphSize + gap;
  }
  if (textHeight > 0) {
    [_altText drawInRect:CGRectMake(kBlockTextPadding, top, MAX(0, box.size.width - kBlockTextPadding * 2), textHeight)
          withAttributes:attributes];
  }
}

// Drawn from paths rather than an SF Symbol so that iOS, macOS and Android show the same shape.
- (void)drawGlyphInRect:(CGRect)rect
{
  RCTUIColor *color = [_color colorWithAlphaComponent:kGlyphAlpha];
  CGFloat size = rect.size.width;
  CGFloat lineWidth = MAX(1.0, size * 0.08);
  CGRect frame = CGRectInset(rect, lineWidth / 2.0, size * 0.14);
  CGFloat width = frame.size.width;
  CGFloat height = frame.size.height;

  UIBezierPath *outline = UIBezierPathWithRoundedRect(frame, size * 0.12);
  outline.lineWidth = lineWidth;
  [color setStroke];
  [outline stroke];

  [color setFill];
  CGFloat sunSize = size * 0.16;
  [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(CGRectGetMinX(frame) + width * 0.62,
                                                     CGRectGetMinY(frame) + height * 0.18, sunSize, sunSize)] fill];

  CGFloat floor = CGRectGetMaxY(frame) - lineWidth;
  CGFloat left = CGRectGetMinX(frame) + lineWidth;
  CGFloat right = CGRectGetMaxX(frame) - lineWidth;
  UIBezierPath *hills = [UIBezierPath bezierPath];
  [hills moveToPoint:CGPointMake(left, floor)];
  BezierPathAddLine(hills, CGPointMake(CGRectGetMinX(frame) + width * 0.36, CGRectGetMinY(frame) + height * 0.42));
  BezierPathAddLine(hills, CGPointMake(CGRectGetMinX(frame) + width * 0.56, CGRectGetMinY(frame) + height * 0.70));
  BezierPathAddLine(hills, CGPointMake(CGRectGetMinX(frame) + width * 0.70, CGRectGetMinY(frame) + height * 0.54));
  BezierPathAddLine(hills, CGPointMake(right, floor));
  [hills closePath];
  [hills fill];
}

@end
