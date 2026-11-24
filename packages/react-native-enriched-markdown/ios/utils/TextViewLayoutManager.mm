#import "TextViewLayoutManager.h"
#import "BlockquoteBorder.h"
#import "CodeBackground.h"
#import "CodeBlockBackground.h"
#import "ENRMStreamingEffects.h"
#import "ENRMTextHighlight.h"
#import "ENRMTextViewport.h"
#import "ListMarkerDrawer.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

// This class is set onto layout managers the text view already made (ENRMTextViewSetup), so it has
// no ivars of its own: their storage would lie past the instance. Its state is associated instead.
@implementation TextViewLayoutManager

#if !TARGET_OS_OSX
static char kGlyphColorKey;

- (void)drawGlyphsForGlyphRange:(NSRange)glyphRange atPoint:(CGPoint)origin color:(UIColor *)color
{
  objc_setAssociatedObject(self, &kGlyphColorKey, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [self drawGlyphsForGlyphRange:glyphRange atPoint:origin];
  objc_setAssociatedObject(self, &kGlyphColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)showCGGlyphs:(const CGGlyph *)glyphs
           positions:(const CGPoint *)positions
               count:(NSInteger)glyphCount
                font:(UIFont *)font
          textMatrix:(CGAffineTransform)textMatrix
          attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
           inContext:(CGContextRef)context
{
  UIColor *glyphColor = objc_getAssociatedObject(self, &kGlyphColorKey);
  if (glyphColor != nil) {
    NSMutableDictionary<NSAttributedStringKey, id> *colored = [attributes mutableCopy];
    colored[NSForegroundColorAttributeName] = glyphColor;
    attributes = colored;
    CGContextSetFillColorWithColor(context, glyphColor.CGColor);
  }
  [super showCGGlyphs:glyphs
            positions:positions
                count:glyphCount
                 font:font
           textMatrix:textMatrix
           attributes:attributes
            inContext:context];
}

// A text view drawing its text itself (ENRMTextViewportView) hears of what to redraw from here too.
// Called while the text storage edits too: nothing here may generate glyphs.
- (void)invalidateDisplayForGlyphRange:(NSRange)glyphRange
{
  [super invalidateDisplayForGlyphRange:glyphRange];
  id textView =
      self.textContainers.count > 0 ? objc_getAssociatedObject(self.textContainers.firstObject, kTextViewKey) : nil;
  if ([textView conformsToProtocol:@protocol(ENRMTextViewportView)]) {
    [(id<ENRMTextViewportView>)textView setNeedsDisplayFromGlyphIndex:glyphRange.location];
  }
}

// TextKit doesn't pass every character range on as a glyph range (an attachment resized after its
// first draw), so the tiles hear of the range here too.
- (void)invalidateDisplayForCharacterRange:(NSRange)charRange
{
  [super invalidateDisplayForCharacterRange:charRange];
  id textView =
      self.textContainers.count > 0 ? objc_getAssociatedObject(self.textContainers.firstObject, kTextViewKey) : nil;
  if ([textView conformsToProtocol:@protocol(ENRMTextViewportView)]) {
    [(id<ENRMTextViewportView>)textView setNeedsDisplayFromCharacterIndex:charRange.location];
  }
}
#endif

// Set only while a streaming text draws its backgrounds: associated, since the class has no ivars.
static char kDrawingEffectsKey;
static char kDrawingTimeKey;

- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow
                            atPoint:(CGPoint)origin
                            effects:(ENRMStreamingEffects *)effects
                               time:(CFTimeInterval)time
{
  objc_setAssociatedObject(self, &kDrawingEffectsKey, effects, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, &kDrawingTimeKey, @(time), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [self drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];
  objc_setAssociatedObject(self, &kDrawingEffectsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, &kDrawingTimeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGFloat)visibilityOfCharactersInRange:(NSRange)range
{
  ENRMStreamingEffects *effects = objc_getAssociatedObject(self, &kDrawingEffectsKey);
  if (!effects) {
    return 1;
  }
  return [effects visibilityOfCharactersInRange:range
                                           time:[objc_getAssociatedObject(self, &kDrawingTimeKey) doubleValue]];
}

- (void)drawBackgroundForGlyphRange:(NSRange)glyphsToShow atPoint:(CGPoint)origin
{
  // 1. UIKit standard background drawing
  [super drawBackgroundForGlyphRange:glyphsToShow atPoint:origin];

  NSTextStorage *storage = self.textStorage;
  if (!storage || storage.length == 0)
    return;

  // 2. Safely get the container and config
  NSTextContainer *textContainer = [self textContainerForGlyphAtIndex:glyphsToShow.location effectiveRange:NULL];
  if (!textContainer)
    return;

  StyleConfig *config = self.config;
  if (!config) {
    ENRMDrawTextHighlights(self.textHighlights, self, glyphsToShow, origin);
    return;
  }

  // 3. Draw specialized layers
  // We fetch the objects into local variables FIRST to ensure they don't
  // disappear mid-method if setConfig: is called on another thread.

  CodeBackground *codeBg = [self getCodeBackgroundWithConfig:config];
  [codeBg drawBackgroundsForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  CodeBlockBackground *codeBlockBg = [self getCodeBlockBackgroundWithConfig:config];
  [codeBlockBg drawBackgroundsForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  BlockquoteBorder *quoteBorder = [self getBlockquoteBorderWithConfig:config];
  [quoteBorder drawBordersForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  // After the code and quote backgrounds, so highlighted code and quotes show it.
  ENRMDrawTextHighlights(self.textHighlights, self, glyphsToShow, origin);

  ListMarkerDrawer *markerDrawer = [self getListMarkerDrawerWithConfig:config];
  [markerDrawer drawMarkersForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];
}

#pragma mark - Decoration baseline correction

/// Returns the NSBaselineOffsetAttributeName value for the first character in
/// the given glyph range, or 0 when the attribute is absent.
///
/// applyBaselineOffset (ParagraphStyleUtils) shifts glyphs upward so text is
/// vertically centered within a line height larger than the font's natural
/// height.  TextKit 1 does not account for this shift when drawing underline
/// and strikethrough decorations — it draws them at the original, unshifted
/// baseline.  Reading the attribute here lets the draw overrides below
/// compensate by the same amount.
- (CGFloat)baselineShiftForGlyphRange:(NSRange)glyphRange
{
  NSTextStorage *storage = self.textStorage;
  if (!storage || storage.length == 0)
    return 0;

  NSUInteger charIndex = [self characterIndexForGlyphAtIndex:glyphRange.location];
  if (charIndex >= storage.length)
    return 0;

  NSNumber *offset = [storage attribute:NSBaselineOffsetAttributeName atIndex:charIndex effectiveRange:NULL];
  return offset ? offset.doubleValue : 0;
}

- (void)drawUnderlineForGlyphRange:(NSRange)glyphRange
                     underlineType:(NSUnderlineStyle)underlineVal
                    baselineOffset:(CGFloat)baselineOffset
                  lineFragmentRect:(CGRect)lineRect
            lineFragmentGlyphRange:(NSRange)lineGlyphRange
                   containerOrigin:(CGPoint)containerOrigin
{
  CGFloat shift = [self baselineShiftForGlyphRange:glyphRange];
  [super drawUnderlineForGlyphRange:glyphRange
                      underlineType:underlineVal
                     baselineOffset:baselineOffset + shift
                   lineFragmentRect:lineRect
             lineFragmentGlyphRange:lineGlyphRange
                    containerOrigin:containerOrigin];
}

- (void)drawStrikethroughForGlyphRange:(NSRange)glyphRange
                     strikethroughType:(NSUnderlineStyle)strikethroughVal
                        baselineOffset:(CGFloat)baselineOffset
                      lineFragmentRect:(CGRect)lineRect
                lineFragmentGlyphRange:(NSRange)lineGlyphRange
                       containerOrigin:(CGPoint)containerOrigin
{
  CGFloat shift = [self baselineShiftForGlyphRange:glyphRange];
  [super drawStrikethroughForGlyphRange:glyphRange
                      strikethroughType:strikethroughVal
                         baselineOffset:baselineOffset + shift
                       lineFragmentRect:lineRect
                 lineFragmentGlyphRange:lineGlyphRange
                        containerOrigin:containerOrigin];
}

#pragma mark - Safe Property Accessors

// We split these into explicit methods to avoid the 'code 257' pointer corruption
// that can happen with generic 'id' factory blocks.

- (CodeBackground *)getCodeBackgroundWithConfig:(StyleConfig *)config
{
  CodeBackground *obj = objc_getAssociatedObject(self, kCodeBackgroundKey);
  if (!obj) {
    obj = [[CodeBackground alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kCodeBackgroundKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

- (BlockquoteBorder *)getBlockquoteBorderWithConfig:(StyleConfig *)config
{
  BlockquoteBorder *obj = objc_getAssociatedObject(self, kBlockquoteBorderKey);
  if (!obj) {
    obj = [[BlockquoteBorder alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kBlockquoteBorderKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

- (ListMarkerDrawer *)getListMarkerDrawerWithConfig:(StyleConfig *)config
{
  ListMarkerDrawer *obj = objc_getAssociatedObject(self, kListMarkerDrawerKey);
  if (!obj) {
    obj = [[ListMarkerDrawer alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kListMarkerDrawerKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

- (CodeBlockBackground *)getCodeBlockBackgroundWithConfig:(StyleConfig *)config
{
  CodeBlockBackground *obj = objc_getAssociatedObject(self, kCodeBlockBackgroundKey);
  if (!obj) {
    obj = [[CodeBlockBackground alloc] initWithConfig:config];
    objc_setAssociatedObject(self, kCodeBlockBackgroundKey, obj, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  return obj;
}

#pragma mark - Highlights

// An associated object, not an ivar: text views get this class through
// object_setClass, which cannot add storage.
- (NSArray<ENRMTextHighlight *> *)textHighlights
{
  return objc_getAssociatedObject(self, kTextHighlightsKey) ?: @[];
}

- (void)setTextHighlights:(NSArray<ENRMTextHighlight *> *)textHighlights
{
  NSArray<ENRMTextHighlight *> *previous = self.textHighlights;
  if ([previous isEqualToArray:textHighlights]) {
    return;
  }
  objc_setAssociatedObject(self, kTextHighlightsKey, [textHighlights copy], OBJC_ASSOCIATION_COPY_NONATOMIC);
  NSUInteger length = self.textStorage.length;
  for (NSArray<ENRMTextHighlight *> *list in @[ previous, textHighlights ]) {
    for (ENRMTextHighlight *highlight in list) {
      NSRange range = NSIntersectionRange(highlight.range, NSMakeRange(0, length));
      if (range.length > 0) {
        [self invalidateDisplayForCharacterRange:[self displayRangeForHighlight:highlight range:range]];
      }
    }
  }
}

// Padding can reach past the highlight's own lines, so every line the padded
// box covers redraws too.
- (NSRange)displayRangeForHighlight:(ENRMTextHighlight *)highlight range:(NSRange)range
{
  NSTextContainer *container = self.textContainers.firstObject;
  if (highlight.padding <= 0 || container == nil) {
    return range;
  }
  CGRect area = ENRMTextHighlightBounds([highlight highlightWithRange:range], self);
  if (CGRectIsNull(area)) {
    return range;
  }
  NSRange glyphs = [self glyphRangeForBoundingRect:area inTextContainer:container];
  return NSUnionRange(range, [self characterRangeForGlyphRange:glyphs actualGlyphRange:NULL]);
}

#pragma mark - Configuration

- (StyleConfig *)config
{
  return objc_getAssociatedObject(self, kStyleConfigKey);
}

- (void)setConfig:(StyleConfig *)config
{
  // We use the same key but clear dependencies first to ensure no stale pointers exist
  objc_setAssociatedObject(self, kCodeBackgroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, kCodeBlockBackgroundKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, kBlockquoteBorderKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(self, kListMarkerDrawerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  objc_setAssociatedObject(self, kStyleConfigKey, config, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

  // Force a full redraw
  [self invalidateDisplayForCharacterRange:NSMakeRange(0, self.textStorage.length)];
}

@end