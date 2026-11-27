#import "ThematicBreakAttachment.h"

// The text draws a rule again on every frame of a streaming animation, and a document's rules look
// alike: they share one image per look. The color is keyed as resolved, so a dynamic one draws again
// when the appearance changes.
static NSCache<NSString *, RCTUIImage *> *ENRMThematicBreakImages(void)
{
  static NSCache<NSString *, RCTUIImage *> *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cache = [[NSCache alloc] init];
    // A rule's look changes with its width and style: a few per screen.
    cache.countLimit = 16;
  });
  return cache;
}

static NSString *ENRMColorKey(CGColorRef color)
{
  if (color == NULL) {
    return @"none";
  }
  NSString *space = (__bridge_transfer NSString *)CGColorSpaceCopyName(CGColorGetColorSpace(color));
  NSMutableString *key = [NSMutableString stringWithString:space ?: @"?"];
  const CGFloat *components = CGColorGetComponents(color);
  for (size_t i = 0; i < CGColorGetNumberOfComponents(color); i++) {
    [key appendFormat:@",%.4f", components[i]];
  }
  return key;
}

@implementation ThematicBreakAttachment

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
  NSString *key = [NSString stringWithFormat:@"%.2f,%.2f,%.2f,%.2f,%@", imageBounds.size.width, imageBounds.size.height,
                                             self.lineHeight, self.marginTop, ENRMColorKey(self.lineColor.CGColor)];
  NSCache<NSString *, RCTUIImage *> *cache = ENRMThematicBreakImages();
  RCTUIImage *cached = [cache objectForKey:key];
  if (cached != nil) {
    return cached;
  }

  // The cache outlives the attachment: the drawing takes copies of its style, not `self`.
  RCTUIColor *lineColor = self.lineColor;
  CGFloat lineHeight = self.lineHeight;
  CGFloat lineY = self.marginTop + (lineHeight / 2.0);
  CGFloat width = imageBounds.size.width;
  RCTUIGraphicsImageRenderer *renderer = [[RCTUIGraphicsImageRenderer alloc] initWithSize:imageBounds.size];
  RCTUIImage *image = [renderer imageWithActions:^(RCTUIGraphicsImageRendererContext *_Nonnull rendererContext) {
    CGContextRef ctx = rendererContext.CGContext;
    [lineColor setStroke];
    CGContextSetLineWidth(ctx, lineHeight);
    CGContextMoveToPoint(ctx, 0, lineY);
    CGContextAddLineToPoint(ctx, width, lineY);
    CGContextStrokePath(ctx);
  }];
  [cache setObject:image forKey:key];
  return image;
}

@end
