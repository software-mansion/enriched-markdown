#import "ThematicBreakAttachment.h"

@implementation ThematicBreakAttachment {
  // The line as last drawn: the text draws it again on every frame of a streaming animation. The
  // color is kept as resolved, so a dynamic one draws again when the appearance changes.
  RCTUIImage *_lineImage;
  CGSize _lineImageSize;
  CGColorRef _lineImageColor;
  CGFloat _lineImageHeight;
  CGFloat _lineImageMarginTop;
}

- (CGRect)attachmentBoundsForTextContainer:(NSTextContainer *)textContainer
                      proposedLineFragment:(CGRect)lineFrag
                             glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex
{
  CGFloat totalHeight = self.marginTop + self.lineHeight + self.marginBottom;
  return CGRectMake(0, 0, CGRectGetWidth(lineFrag), totalHeight);
}

- (RCTUIImage *)imageForBounds:(CGRect)imageBounds
                 textContainer:(NSTextContainer *)textContainer
                characterIndex:(NSUInteger)charIndex
{
  CGColorRef color = self.lineColor.CGColor;
  if (_lineImage != nil && CGSizeEqualToSize(_lineImageSize, imageBounds.size) &&
      CGColorEqualToColor(_lineImageColor, color) && _lineImageHeight == self.lineHeight &&
      _lineImageMarginTop == self.marginTop) {
    return _lineImage;
  }
  _lineImageSize = imageBounds.size;
  CGColorRelease(_lineImageColor);
  _lineImageColor = CGColorRetain(color);
  _lineImageHeight = self.lineHeight;
  _lineImageMarginTop = self.marginTop;

  RCTUIGraphicsImageRenderer *renderer = [[RCTUIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];

  _lineImage = [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *_Nonnull rendererContext) {
    CGContextRef ctx = rendererContext.CGContext;

    CGFloat lineY = self.marginTop + (self.lineHeight / 2.0);

    [self.lineColor setStroke];
    CGContextSetLineWidth(ctx, self.lineHeight);
    CGContextMoveToPoint(ctx, 0, lineY);
    CGContextAddLineToPoint(ctx, imageBounds.size.width, lineY);
    CGContextStrokePath(ctx);
  }];
  return _lineImage;
}

- (void)dealloc
{
  CGColorRelease(_lineImageColor);
}

@end
