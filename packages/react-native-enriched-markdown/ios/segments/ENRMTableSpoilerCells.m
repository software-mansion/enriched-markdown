#import "ENRMTableSpoilerCells.h"
#import "ENRMSpoilerOverlayManager.h"
#import "ENRMSpoilerTapUtils.h"

#if !TARGET_OS_OSX
@interface ENRMTableSpoilerClipView : UIView
@end
@implementation ENRMTableSpoilerClipView
- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.clipsToBounds = YES;
    self.userInteractionEnabled = NO;
  }
  return self;
}
@end
#else
@interface ENRMTableSpoilerClipView : NSView
@end
@implementation ENRMTableSpoilerClipView
- (instancetype)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.wantsLayer = YES;
    self.layer.masksToBounds = YES;
  }
  return self;
}
- (BOOL)isFlipped
{
  return YES;
}
- (NSView *)hitTest:(NSPoint)point
{
  return nil;
}
@end
#endif

static BOOL ENRMTextHasSpoiler(NSAttributedString *text)
{
  __block BOOL found = NO;
  [text enumerateAttribute:SpoilerAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:NSAttributedStringEnumerationLongestEffectiveRangeNotRequired
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if (value) {
                    found = YES;
                    *stop = YES;
                  }
                }];
  return found;
}

static NSArray<NSValue *> *ENRMSpoilerRanges(NSAttributedString *text)
{
  NSMutableArray<NSValue *> *ranges = [NSMutableArray array];
  [text enumerateAttribute:SpoilerAttributeName
                   inRange:NSMakeRange(0, text.length)
                   options:0
                usingBlock:^(id value, NSRange range, BOOL *stop) {
                  if (value)
                    [ranges addObject:[NSValue valueWithRange:range]];
                }];
  return ranges;
}

NSArray<NSNumber *> *ENRMTableOffsets(NSArray<NSNumber *> *sizes)
{
  NSMutableArray<NSNumber *> *offsets = [NSMutableArray arrayWithCapacity:sizes.count];
  CGFloat offset = 0;
  for (NSNumber *size in sizes) {
    [offsets addObject:@(offset)];
    offset += size.doubleValue;
  }
  return offsets;
}

@interface ENRMTableSpoilerCell : NSObject <ENRMSpoilerTextLayout>
@property (nonatomic, strong) NSMutableAttributedString *cellText;
@property (nonatomic, copy) NSString *cellString;
@property (nonatomic, copy) NSArray<NSValue *> *spoilerRanges;
@property (nonatomic, strong) NSMutableArray<NSValue *> *revealedRanges;
@property (nonatomic, strong) NSTextStorage *textStorage;
@property (nonatomic, strong) NSLayoutManager *layoutManager;
@property (nonatomic, strong) NSTextContainer *textContainer;
@property (nonatomic, strong) ENRMTableSpoilerClipView *clipView;
@property (nonatomic, strong, nullable) RCTUIColor *spoilerBackgroundColor;
@property (nonatomic, assign) CGRect textRect;
@property (nonatomic, strong) ENRMSpoilerOverlayManager *manager;
@end

@implementation ENRMTableSpoilerCell

- (instancetype)initWithText:(NSMutableAttributedString *)text host:(RCTUIView *)host config:(StyleConfig *)config
{
  if (self = [super init]) {
    _cellText = text;
    _cellString = [text.string copy];
    _spoilerRanges = ENRMSpoilerRanges(text);
    _revealedRanges = [NSMutableArray array];
    _textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
    _layoutManager = [[NSLayoutManager alloc] init];
    _textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    _textContainer.lineFragmentPadding = 0;
    [_layoutManager addTextContainer:_textContainer];
    [_textStorage addLayoutManager:_layoutManager];
    _clipView = [[ENRMTableSpoilerClipView alloc] initWithFrame:CGRectZero];
    [host addSubview:_clipView];
    _manager = [[ENRMSpoilerOverlayManager alloc] initWithLayout:self config:config];
  }
  return self;
}

- (BOOL)showsText:(NSAttributedString *)text
{
  return [_cellString isEqualToString:text.string] && [_spoilerRanges isEqualToArray:ENRMSpoilerRanges(text)];
}

- (void)adoptText:(NSMutableAttributedString *)text host:(RCTUIView *)host
{
  _cellText = text;
  [_textStorage setAttributedString:text];
  for (NSValue *value in _revealedRanges) {
    ENRMRevealSpoilerInRange(_textStorage, value.rangeValue);
    ENRMRevealSpoilerInRange(_cellText, value.rangeValue);
  }
  if (_clipView.superview != host) {
    [host addSubview:_clipView];
  }
  [_manager setNeedsUpdate];
}

- (RCTUIView *)spoilerOverlayHost
{
  return _clipView;
}

- (CGPoint)spoilerTextOrigin
{
  CGRect clip = _clipView.frame;
  return CGPointMake(_textRect.origin.x - clip.origin.x, _textRect.origin.y - clip.origin.y);
}

- (void)setOpacity:(CGFloat)opacity
{
#if !TARGET_OS_OSX
  _clipView.alpha = opacity;
#else
  _clipView.alphaValue = opacity;
#endif
}

- (BOOL)spoilerLayoutReady
{
  return _textContainer.size.width > 0;
}

- (void)layoutInRect:(CGRect)textRect cellRect:(CGRect)cellRect
{
  if (!CGRectEqualToRect(_clipView.frame, cellRect)) {
    _clipView.frame = cellRect;
  }
  if (!CGSizeEqualToSize(_textContainer.size, textRect.size)) {
    _textContainer.size = textRect.size;
  }
  _textRect = textRect;
  [_manager setNeedsUpdate];
  [_manager updateIfNeeded];
}

- (NSUInteger)hiddenCharacterAtPoint:(CGPoint)point
{
  if (!CGRectContainsPoint(_textRect, point))
    return NSNotFound;
  CGPoint local = CGPointMake(point.x - _textRect.origin.x, point.y - _textRect.origin.y);
  [_layoutManager ensureLayoutForTextContainer:_textContainer];
  CGFloat fraction = 0;
  NSUInteger glyphIndex = [_layoutManager glyphIndexForPoint:local
                                             inTextContainer:_textContainer
                              fractionOfDistanceThroughGlyph:&fraction];
  if (glyphIndex >= _layoutManager.numberOfGlyphs)
    return NSNotFound;
  CGRect glyphRect = [_layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                               inTextContainer:_textContainer];
  if (!CGRectContainsPoint(glyphRect, local))
    return NSNotFound;
  NSUInteger charIndex = [_layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  if (charIndex >= _textStorage.length || ![_textStorage attribute:SpoilerAttributeName
                                                           atIndex:charIndex
                                                    effectiveRange:NULL])
    return NSNotFound;
  return charIndex;
}

- (BOOL)revealAtPoint:(CGPoint)point
{
  NSUInteger charIndex = [self hiddenCharacterAtPoint:point];
  if (charIndex == NSNotFound)
    return NO;
  NSRange revealed = ENRMRevealSpoilerAtIndex(_textStorage, charIndex);
  if (revealed.location == NSNotFound)
    return NO;
  ENRMRevealSpoilerInRange(_cellText, revealed);
  [_revealedRanges addObject:[NSValue valueWithRange:revealed]];
  [_manager removeOverlaysForCharRange:revealed];
  return YES;
}

- (void)removeOverlays
{
  [_manager removeAllOverlays];
  [_clipView removeFromSuperview];
}

@end

@implementation ENRMTableSpoilerCells {
  __weak RCTUIView *_host;
  NSMutableDictionary<NSIndexPath *, ENRMTableSpoilerCell *> *_cells;
}

- (instancetype)initWithHost:(RCTUIView *)host
{
  if (self = [super init]) {
    _host = host;
  }
  return self;
}

- (void)setSpoilerOverlay:(ENRMSpoilerOverlay)spoilerOverlay
{
  _spoilerOverlay = spoilerOverlay;
  for (ENRMTableSpoilerCell *cell in _cells.allValues) {
    cell.manager.spoilerOverlay = spoilerOverlay;
  }
}

- (void)syncWithTexts:(NSArray<NSArray<NSAttributedString *> *> *)texts backgrounds:(NSArray<RCTUIColor *> *)backgrounds
{
  RCTUIView *host = _host;
  NSMutableDictionary<NSIndexPath *, ENRMTableSpoilerCell *> *cells = [NSMutableDictionary dictionary];
  for (NSUInteger r = 0; r < texts.count; r++) {
    NSArray<NSAttributedString *> *rowTexts = texts[r];
    for (NSUInteger c = 0; c < rowTexts.count; c++) {
      NSAttributedString *text = rowTexts[c];
      if (!host || ![text isKindOfClass:[NSMutableAttributedString class]])
        continue;
      NSIndexPath *key = [NSIndexPath indexPathWithIndexes:(NSUInteger[]){r, c} length:2];
      ENRMTableSpoilerCell *cell = _cells[key];
      if (cell && cell.cellText == text) {
      } else if (cell && [cell showsText:text]) {
        [cell adoptText:(NSMutableAttributedString *)text host:host];
      } else if (ENRMTextHasSpoiler(text)) {
        cell = [[ENRMTableSpoilerCell alloc] initWithText:(NSMutableAttributedString *)text host:host config:_config];
        cell.spoilerBackgroundColor = r < backgrounds.count ? backgrounds[r] : nil;
        cell.manager.spoilerOverlay = _spoilerOverlay;
      } else {
        continue;
      }
      cells[key] = cell;
    }
  }
  for (NSIndexPath *key in _cells) {
    if (cells[key] != _cells[key]) {
      [_cells[key] removeOverlays];
    }
  }
  _cells = cells.count ? cells : nil;
}

- (void)layoutWithTextRect:(ENRMTableCellTextRect)textRect
{
  [_cells enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *key, ENRMTableSpoilerCell *cell, BOOL *stop) {
    CGRect cellRect = CGRectZero;
    CGRect text = textRect([key indexAtPosition:0], [key indexAtPosition:1], &cellRect);
    [cell layoutInRect:text cellRect:cellRect];
  }];
}

- (void)setOpacityOfRows:(CGFloat (^)(NSUInteger row))opacityOfRow
{
  [_cells enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *key, ENRMTableSpoilerCell *cell, BOOL *stop) {
    [cell setOpacity:opacityOfRow([key indexAtPosition:0])];
  }];
}

- (ENRMTableSpoilerCell *)cellAtPoint:(CGPoint)point
{
  for (ENRMTableSpoilerCell *cell in _cells.allValues) {
    if (CGRectContainsPoint(cell.textRect, point) && CGRectContainsPoint(cell.clipView.frame, point))
      return cell;
  }
  return nil;
}

- (BOOL)revealAtPoint:(CGPoint)point
{
  return [[self cellAtPoint:point] revealAtPoint:point];
}

- (BOOL)hasSpoilerAtPoint:(CGPoint)point
{
  ENRMTableSpoilerCell *cell = [self cellAtPoint:point];
  return cell && [cell hiddenCharacterAtPoint:point] != NSNotFound;
}

@end
