#import "TextViewLayoutManager.h"
#import "BlockquoteBorder.h"
#import "CodeBackground.h"
#import "CodeBlockBackground.h"
#import "ListMarkerDrawer.h"
#import "RuntimeKeys.h"
#import "StyleConfig.h"
#import <objc/runtime.h>

// Holds the host weakly: the layout manager can outlive its text view (it is detached and
// reattached as the view is recycled), and an associated object cannot be weak itself.
@interface ENRMBackgroundFillsHostBox : NSObject
@property (nonatomic, weak) id<ENRMBackgroundFillsHost> host;
@end
@implementation ENRMBackgroundFillsHostBox
@end

@implementation TextViewLayoutManager

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
  if (!config)
    return;

  // 3. Draw specialized layers
  // We fetch the objects into local variables FIRST to ensure they don't
  // disappear mid-method if setConfig: is called on another thread.
  ENRMBackgroundFillMode fillMode = self.backgroundFillsHost ? ENRMBackgroundFillModeSkip : ENRMBackgroundFillModePaint;

  CodeBackground *codeBg = [self getCodeBackgroundWithConfig:config];
  codeBg.fillMode = fillMode;
  [codeBg drawBackgroundsForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  CodeBlockBackground *codeBlockBg = [self getCodeBlockBackgroundWithConfig:config];
  codeBlockBg.fillMode = fillMode;
  [codeBlockBg drawBackgroundsForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

  BlockquoteBorder *quoteBorder = [self getBlockquoteBorderWithConfig:config];
  quoteBorder.fillMode = fillMode;
  [quoteBorder drawBordersForGlyphRange:glyphsToShow layoutManager:self textContainer:textContainer atPoint:origin];

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
  [self.backgroundFillsHost setNeedsBackgroundFillsUpdate];
}

#pragma mark - Background fills

static char kBackgroundFillsHostKey;

- (id<ENRMBackgroundFillsHost>)backgroundFillsHost
{
  return ((ENRMBackgroundFillsHostBox *)objc_getAssociatedObject(self, &kBackgroundFillsHostKey)).host;
}

- (void)setBackgroundFillsHost:(id<ENRMBackgroundFillsHost>)host
{
  if (host == self.backgroundFillsHost)
    return;
  ENRMBackgroundFillsHostBox *box = [[ENRMBackgroundFillsHostBox alloc] init];
  box.host = host;
  objc_setAssociatedObject(self, &kBackgroundFillsHostKey, box, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  // The text pass starts or stops painting the fills.
  [self invalidateDisplayForCharacterRange:NSMakeRange(0, self.textStorage.length)];
}

- (void)enumerateBackgroundFillsAtPoint:(CGPoint)origin usingBlock:(ENRMBackgroundFillSink)block
{
  NSTextContainer *textContainer = self.textContainers.firstObject;
  StyleConfig *config = self.config;
  if (!textContainer || !config || self.textStorage.length == 0)
    return;

  NSRange glyphRange = [self glyphRangeForTextContainer:textContainer];
  if (glyphRange.length == 0)
    return;

  CodeBackground *codeBg = [self getCodeBackgroundWithConfig:config];
  CodeBlockBackground *codeBlockBg = [self getCodeBlockBackgroundWithConfig:config];
  BlockquoteBorder *quoteBorder = [self getBlockquoteBorderWithConfig:config];

  codeBg.fillMode = codeBlockBg.fillMode = quoteBorder.fillMode = ENRMBackgroundFillModeCollect;
  codeBg.fillSink = codeBlockBg.fillSink = quoteBorder.fillSink = block;

  // Same order as drawBackgroundForGlyphRange:atPoint: paints them, so later fills stack on top.
  [codeBg drawBackgroundsForGlyphRange:glyphRange layoutManager:self textContainer:textContainer atPoint:origin];
  [codeBlockBg drawBackgroundsForGlyphRange:glyphRange layoutManager:self textContainer:textContainer atPoint:origin];
  [quoteBorder drawBordersForGlyphRange:glyphRange layoutManager:self textContainer:textContainer atPoint:origin];

  codeBg.fillSink = codeBlockBg.fillSink = quoteBorder.fillSink = nil;
  codeBg.fillMode = codeBlockBg.fillMode = quoteBorder.fillMode = ENRMBackgroundFillModeSkip;
}

/// Images settling, streamed text and re-renders all invalidate layout through here.
- (void)invalidateLayoutForCharacterRange:(NSRange)charRange actualCharacterRange:(NSRangePointer)actualCharRange
{
  [super invalidateLayoutForCharacterRange:charRange actualCharacterRange:actualCharRange];
  [self.backgroundFillsHost setNeedsBackgroundFillsUpdate];
}

@end