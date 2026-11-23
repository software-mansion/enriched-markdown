#import "ENRMTableIOSGridView.h"
#import "ENRMDroppableContent.h"
#import "ENRMSpoilerOverlayManager.h"
#import "ENRMSpoilerTapUtils.h"
#import "LinkTapUtils.h"

#if !TARGET_OS_OSX

@interface ENRMTableIOSGridView () <UIGestureRecognizerDelegate, ENRMDroppableContent>
@end

// Where text sits across its cell: 0 at the left, 0.5 centred, 1 at the right.
static CGFloat ENRMTableTextAnchor(NSAttributedString *text)
{
  NSParagraphStyle *style = [text attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL];
  BOOL rightToLeft = style.baseWritingDirection == NSWritingDirectionRightToLeft;
  switch (style.alignment) {
    case NSTextAlignmentCenter:
      return 0.5;
    case NSTextAlignmentRight:
      return 1;
    case NSTextAlignmentLeft:
      return 0;
    default:
      return rightToLeft ? 1 : 0;
  }
}

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

@interface ENRMTableSpoilerCell : NSObject <ENRMSpoilerTextLayout>
@property (nonatomic, strong) NSMutableAttributedString *cellText;
@property (nonatomic, strong) NSTextStorage *textStorage;
@property (nonatomic, strong) NSLayoutManager *layoutManager;
@property (nonatomic, strong) NSTextContainer *textContainer;
@property (nonatomic, weak) UIView *spoilerOverlayHost;
@property (nonatomic, assign) CGPoint spoilerTextOrigin;
@property (nonatomic, strong) ENRMSpoilerOverlayManager *manager;
@property (nonatomic, strong, nullable) UIColor *spoilerBackgroundColor;
@end

@implementation ENRMTableSpoilerCell

- (instancetype)initWithText:(NSMutableAttributedString *)text host:(UIView *)host config:(StyleConfig *)config
{
  if (self = [super init]) {
    _cellText = text;
    _textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
    _layoutManager = [[NSLayoutManager alloc] init];
    _textContainer = [[NSTextContainer alloc] initWithSize:CGSizeZero];
    _textContainer.lineFragmentPadding = 0;
    [_layoutManager addTextContainer:_textContainer];
    [_textStorage addLayoutManager:_layoutManager];
    _spoilerOverlayHost = host;
    _manager = [[ENRMSpoilerOverlayManager alloc] initWithLayout:self config:config];
  }
  return self;
}

- (BOOL)spoilerLayoutReady
{
  return _textContainer.size.width > 0;
}

- (void)layoutInRect:(CGRect)textRect
{
  if (!CGSizeEqualToSize(_textContainer.size, textRect.size)) {
    _textContainer.size = textRect.size;
  }
  _spoilerTextOrigin = textRect.origin;
  [_manager setNeedsUpdate];
  [_manager updateIfNeeded];
}

- (BOOL)revealAtPoint:(CGPoint)point
{
  CGPoint local = CGPointMake(point.x - _spoilerTextOrigin.x, point.y - _spoilerTextOrigin.y);
  [_layoutManager ensureLayoutForTextContainer:_textContainer];
  CGFloat fraction = 0;
  NSUInteger glyphIndex = [_layoutManager glyphIndexForPoint:local
                                             inTextContainer:_textContainer
                              fractionOfDistanceThroughGlyph:&fraction];
  if (glyphIndex >= _layoutManager.numberOfGlyphs)
    return NO;
  CGRect glyphRect = [_layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                               inTextContainer:_textContainer];
  if (!CGRectContainsPoint(glyphRect, local))
    return NO;
  NSUInteger charIndex = [_layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  NSRange revealed = ENRMRevealSpoilerAtIndex(_textStorage, charIndex);
  if (revealed.location == NSNotFound)
    return NO;
  ENRMRevealSpoilerInRange(_cellText, revealed);
  [_manager removeOverlaysForCharRange:revealed];
  return YES;
}

- (void)removeOverlays
{
  [_manager removeAllOverlays];
}

@end

// Ticks the row fade without the display link retaining the grid.
@interface ENRMTableFadeTicker : NSObject
@property (nonatomic, weak) ENRMTableIOSGridView *grid;
@end

@interface ENRMTableIOSGridView ()
- (void)stepRowFade:(CADisplayLink *)link;
@end

@implementation ENRMTableFadeTicker
- (void)tick:(CADisplayLink *)link
{
  ENRMTableIOSGridView *grid = self.grid;
  if (grid) {
    [grid stepRowFade:link];
  } else {
    [link invalidate];
  }
}
@end

@implementation ENRMTableIOSItemHit
@end

@implementation ENRMTableIOSRowData
@end

@implementation ENRMTableIOSGridView {
  NSArray<ENRMTableIOSRowData *> *_tableRows;
  NSArray<NSNumber *> *_columnWidths;
  NSArray<NSNumber *> *_rowHeights;
  UIColor *_borderColor;
  CGFloat _borderWidth;
  CGFloat _cornerRadius;
  CGFloat _horizontalCellPadding;
  CGFloat _verticalCellPadding;
  NSArray<NSNumber *> *_shownColumnWidths;
  // When each row started fading in; 0 for one shown as it is.
  NSMutableArray<NSNumber *> *_rowFadeStarts;
  NSTimeInterval _rowFadeDuration;
  CADisplayLink *_rowFadeLink;
  NSMutableDictionary<NSIndexPath *, ENRMTableSpoilerCell *> *_spoilerCells;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.contentMode = UIViewContentModeRedraw;
    self.opaque = NO;
    self.accessibilityElementsHidden = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self addGestureRecognizer:tap];

    UILongPressGestureRecognizer *longPress =
        [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.delegate = self;
    [self addGestureRecognizer:longPress];
  }
  return self;
}

#pragma mark - Data

- (void)updateWithRows:(NSArray<ENRMTableIOSRowData *> *)rows
             columnWidths:(NSArray<NSNumber *> *)columnWidths
               rowHeights:(NSArray<NSNumber *> *)rowHeights
              borderColor:(UIColor *)borderColor
              borderWidth:(CGFloat)borderWidth
    horizontalCellPadding:(CGFloat)horizontalCellPadding
      verticalCellPadding:(CGFloat)verticalCellPadding
             cornerRadius:(CGFloat)cornerRadius
{
  _tableRows = [rows copy];
  _columnWidths = [columnWidths copy];
  _rowHeights = [rowHeights copy];
  _borderColor = borderColor;
  _borderWidth = borderWidth;
  _cornerRadius = cornerRadius;
  _horizontalCellPadding = horizontalCellPadding;
  _verticalCellPadding = verticalCellPadding;
  [self syncSpoilerCells];
  [self setNeedsDisplay];
}

#pragma mark - Spoilers

- (void)setSpoilerOverlay:(ENRMSpoilerOverlay)spoilerOverlay
{
  _spoilerOverlay = spoilerOverlay;
  for (ENRMTableSpoilerCell *cell in _spoilerCells.allValues) {
    cell.manager.spoilerOverlay = spoilerOverlay;
  }
}

// Keeps a spoiler cell for each cell whose text holds spoilers. New cell text starts hidden again.
- (void)syncSpoilerCells
{
  NSMutableDictionary<NSIndexPath *, ENRMTableSpoilerCell *> *cells = [NSMutableDictionary dictionary];
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    NSArray<NSAttributedString *> *texts = _tableRows[r].cellTexts;
    for (NSUInteger c = 0; c < texts.count; c++) {
      NSAttributedString *text = texts[c];
      if (![text isKindOfClass:[NSMutableAttributedString class]] || !ENRMTextHasSpoiler(text))
        continue;
      NSIndexPath *key = [NSIndexPath indexPathForRow:r inSection:c];
      ENRMTableSpoilerCell *cell = _spoilerCells[key];
      if (cell.cellText != text) {
        [cell removeOverlays];
        cell = [[ENRMTableSpoilerCell alloc] initWithText:(NSMutableAttributedString *)text
                                                     host:self
                                                   config:_spoilerConfig];
        cell.spoilerBackgroundColor = _tableRows[r].backgroundColor;
        cell.manager.spoilerOverlay = _spoilerOverlay;
      }
      cells[key] = cell;
    }
  }
  for (NSIndexPath *key in _spoilerCells) {
    if (cells[key] != _spoilerCells[key]) {
      [_spoilerCells[key] removeOverlays];
    }
  }
  _spoilerCells = cells.count ? cells : nil;
  [self layoutSpoilerCells];
}

// Places each spoiler cell's text where drawRect: draws it.
- (void)layoutSpoilerCells
{
  if (!_spoilerCells.count)
    return;
  BOOL widthsAnimate = _shownColumnWidths.count == _columnWidths.count;
  NSArray<NSNumber *> *shownWidths = widthsAnimate ? _shownColumnWidths : _columnWidths;
  [_spoilerCells enumerateKeysAndObjectsUsingBlock:^(NSIndexPath *key, ENRMTableSpoilerCell *cell, BOOL *stop) {
    NSUInteger r = key.row, c = key.section;
    if (r >= self->_rowHeights.count || c >= self->_columnWidths.count)
      return;
    CGFloat y = 0;
    for (NSUInteger i = 0; i < r; i++)
      y += [self->_rowHeights[i] doubleValue];
    CGFloat x = 0;
    for (NSUInteger i = 0; i < c; i++)
      x += [shownWidths[i] doubleValue];
    CGFloat laidOutWidth = [self->_columnWidths[c] doubleValue];
    CGFloat shift = ([shownWidths[c] doubleValue] - laidOutWidth) * ENRMTableTextAnchor(cell.cellText);
    CGFloat rowHeight = [self->_rowHeights[r] doubleValue];
    [cell layoutInRect:CGRectMake(x + self->_horizontalCellPadding + shift, y + self->_verticalCellPadding,
                                  laidOutWidth - self->_horizontalCellPadding * 2,
                                  rowHeight - self->_verticalCellPadding * 2)];
  }];
}

- (ENRMTableSpoilerCell *)spoilerCellAtPoint:(CGPoint)point
{
  CGFloat y = 0;
  for (NSUInteger r = 0; r < _rowHeights.count; r++) {
    CGFloat rh = [_rowHeights[r] doubleValue];
    if (point.y >= y && point.y < y + rh) {
      CGFloat x = 0;
      for (NSUInteger c = 0; c < _columnWidths.count; c++) {
        CGFloat cw = [_columnWidths[c] doubleValue];
        if (point.x >= x && point.x < x + cw)
          return _spoilerCells[[NSIndexPath indexPathForRow:r inSection:c]];
        x += cw;
      }
      return nil;
    }
    y += rh;
  }
  return nil;
}

- (void)fadeInRowsFrom:(NSUInteger)startRow duration:(NSTimeInterval)duration
{
  if (startRow >= _tableRows.count)
    return;

  // Each row fades in where it is drawn: a cross-fade of the whole grid would show the old one
  // through it while the columns widen.
  if (_rowFadeStarts == nil) {
    _rowFadeStarts = [NSMutableArray array];
  }
  while (_rowFadeStarts.count < _tableRows.count) {
    [_rowFadeStarts addObject:@0];
  }
  CFTimeInterval now = CACurrentMediaTime();
  for (NSUInteger row = startRow; row < _tableRows.count; row++) {
    _rowFadeStarts[row] = @(now);
  }
  _rowFadeDuration = duration;
  if (_rowFadeLink == nil) {
    ENRMTableFadeTicker *ticker = [[ENRMTableFadeTicker alloc] init];
    ticker.grid = self;
    _rowFadeLink = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
    _rowFadeLink.preferredFrameRateRange = CAFrameRateRangeMake(30, 60, 60);
    [_rowFadeLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
  }
  [self setNeedsDisplay];
}

- (void)finishRowFade
{
  [_rowFadeLink invalidate];
  _rowFadeLink = nil;
  _rowFadeStarts = nil;
  [self setNeedsDisplay];
}

- (void)stepRowFade:(CADisplayLink *)link
{
  CFTimeInterval now = CACurrentMediaTime();
  BOOL fading = NO;
  for (NSNumber *start in _rowFadeStarts) {
    if (start.doubleValue > 0 && now - start.doubleValue < _rowFadeDuration) {
      fading = YES;
      break;
    }
  }
  if (!fading) {
    [self finishRowFade];
    return;
  }
  [self setNeedsDisplay];
}

- (CGFloat)opacityOfRow:(NSUInteger)row at:(CFTimeInterval)now
{
  if (row >= _rowFadeStarts.count || _rowFadeDuration <= 0) {
    return 1;
  }
  double start = _rowFadeStarts[row].doubleValue;
  if (start <= 0) {
    return 1;
  }
  double progress = MIN(1.0, MAX(0.0, (now - start) / _rowFadeDuration));
  return 1 - pow(1 - progress, 2);
}

- (void)setShownColumnWidths:(NSArray<NSNumber *> *)widths
{
  _shownColumnWidths = [widths copy];
  [self setNeedsDisplay];
  [self layoutSpoilerCells];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)dirtyRect
{
  if (!_tableRows.count || !_columnWidths.count || !_rowHeights.count)
    return;

  // Columns moving to their laid-out widths; otherwise the grid draws as it always has.
  BOOL widthsAnimate = _shownColumnWidths.count == _columnWidths.count;
  NSArray<NSNumber *> *shownWidths = widthsAnimate ? _shownColumnWidths : _columnWidths;
  CGContextRef context = UIGraphicsGetCurrentContext();
  CFTimeInterval now = CACurrentMediaTime();
  CGFloat yOffset = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    ENRMTableIOSRowData *rowData = _tableRows[r];
    CGFloat rowHeight = [_rowHeights[r] doubleValue];
    CGFloat opacity = [self opacityOfRow:r at:now];
    if (opacity <= 0) {
      yOffset += rowHeight;
      continue;
    }
    BOOL fading = opacity < 1;
    if (fading) {
      CGContextSaveGState(context);
      CGContextSetAlpha(context, opacity);
    }
    CGFloat xOffset = 0;

    NSUInteger colCount = MIN(rowData.cellTexts.count, _columnWidths.count);
    for (NSUInteger c = 0; c < colCount; c++) {
      CGFloat columnWidth = [shownWidths[c] doubleValue];
      CGFloat textWidth = [_columnWidths[c] doubleValue] - _horizontalCellPadding * 2;
      CGRect cellRect = CGRectMake(xOffset, yOffset, columnWidth + _borderWidth, rowHeight + _borderWidth);

      [rowData.backgroundColor setFill];
      UIRectFill(cellRect);

      [_borderColor setStroke];
      UIBezierPath *border = [UIBezierPath bezierPathWithRect:cellRect];
      border.lineWidth = _borderWidth;
      [border stroke];

      NSAttributedString *text = rowData.cellTexts[c];
      if (text.length > 0) {
        // While the column is narrower than laid out, text keeps its side: trailing text its trailing edge.
        CGFloat shift = (columnWidth - [_columnWidths[c] doubleValue]) * ENRMTableTextAnchor(text);
        CGRect textRect = CGRectMake(xOffset + _horizontalCellPadding + shift, yOffset + _verticalCellPadding,
                                     textWidth, rowHeight - _verticalCellPadding * 2);
        if (widthsAnimate) {
          CGContextSaveGState(context);
          CGContextClipToRect(context, CGRectInset(cellRect, _borderWidth, _borderWidth));
        }
        [text drawWithRect:textRect
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                   context:nil];
        if (widthsAnimate) {
          CGContextRestoreGState(context);
        }
      }

      xOffset += columnWidth;
    }
    if (fading) {
      CGContextRestoreGState(context);
    }
    yOffset += rowHeight;
  }

  // The container's corner mask cuts the square cell strokes; draw the arcs.
  if (_cornerRadius > 0 && _borderWidth > 0) {
    [_borderColor setStroke];
    UIBezierPath *outline = [UIBezierPath bezierPathWithRoundedRect:self.bounds cornerRadius:_cornerRadius];
    outline.lineWidth = _borderWidth;
    [outline stroke];
  }
}

#pragma mark - Link hit-testing

- (BOOL)cellAtPoint:(CGPoint)point
          rowOrigin:(out CGFloat *)outRowY
          rowHeight:(out CGFloat *)outRowH
          colOrigin:(out CGFloat *)outColX
           colWidth:(out CGFloat *)outColW
           cellText:(out NSAttributedString *__autoreleasing *)outText
{
  CGFloat rowY = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    CGFloat rh = [_rowHeights[r] doubleValue];
    if (point.y >= rowY && point.y < rowY + rh) {
      CGFloat colX = 0;
      for (NSUInteger c = 0; c < _columnWidths.count; c++) {
        CGFloat cw = [_columnWidths[c] doubleValue];
        if (point.x >= colX && point.x < colX + cw) {
          ENRMTableIOSRowData *rowData = _tableRows[r];
          if (c >= rowData.cellTexts.count)
            return NO;
          *outRowY = rowY;
          *outRowH = rh;
          *outColX = colX;
          *outColW = cw;
          *outText = rowData.cellTexts[c];
          return YES;
        }
        colX += cw;
      }
      return NO;
    }
    rowY += rh;
  }
  return NO;
}

static ENRMTableIOSItemHit *itemInAttributedString(NSAttributedString *text, CGRect textRect, CGPoint point)
{
  if (text.length == 0)
    return nil;

  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:textRect.size];
  textContainer.lineFragmentPadding = 0;
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGPoint local = CGPointMake(point.x - textRect.origin.x, point.y - textRect.origin.y);
  CGFloat fraction = 0;
  NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:local
                                            inTextContainer:textContainer
                             fractionOfDistanceThroughGlyph:&fraction];
  if (glyphIndex >= layoutManager.numberOfGlyphs)
    return nil;
  NSUInteger charIndex = [layoutManager characterIndexForGlyphAtIndex:glyphIndex];
  if (charIndex >= text.length)
    return nil;

  if ([text attribute:SpoilerAttributeName atIndex:charIndex effectiveRange:NULL])
    return nil;

  NSRange itemRange;
  NSRange whole = NSMakeRange(0, text.length);
  NSString *linkURL = [text attribute:@"linkURL" atIndex:charIndex longestEffectiveRange:&itemRange inRange:whole];
  NSString *imageURL =
      linkURL ? nil : [text attribute:@"imageURL" atIndex:charIndex longestEffectiveRange:&itemRange inRange:whole];
  if (!linkURL && !imageURL)
    return nil;

  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:itemRange actualCharacterRange:NULL];
  CGRect frame = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
  // Links keep nearest-glyph hits; an image needs the tap inside its bounds.
  if (imageURL && !CGRectContainsPoint(frame, local))
    return nil;

  ENRMTableIOSItemHit *hit = [[ENRMTableIOSItemHit alloc] init];
  hit.kind = linkURL ? ENRMTableIOSItemKindLink : ENRMTableIOSItemKindImage;
  hit.url = linkURL ?: imageURL;
  hit.title = linkURL ? linkTitleAtIndex(text, charIndex)
                      : [text attribute:@"imageAltText" atIndex:charIndex effectiveRange:NULL];
  hit.frame = CGRectOffset(frame, textRect.origin.x, textRect.origin.y);
  return hit;
}

- (ENRMTableIOSItemHit *)itemAtPoint:(CGPoint)point
{
  CGFloat rowY, rowH, colX, colW;
  NSAttributedString *text;
  if (![self cellAtPoint:point rowOrigin:&rowY rowHeight:&rowH colOrigin:&colX colWidth:&colW cellText:&text])
    return nil;

  CGRect textRect = CGRectMake(colX + _horizontalCellPadding, rowY + _verticalCellPadding,
                               colW - _horizontalCellPadding * 2, rowH - _verticalCellPadding * 2);
  if (!CGRectContainsPoint(textRect, point))
    return nil;

  return itemInAttributedString(text, textRect, point);
}

- (ENRMTableIOSItemHit *)linkAtPoint:(CGPoint)point
{
  ENRMTableIOSItemHit *hit = [self itemAtPoint:point];
  return hit.kind == ENRMTableIOSItemKindLink ? hit : nil;
}

#pragma mark - Gesture handlers

- (void)handleLinkGesture:(UIGestureRecognizer *)recognizer block:(ENRMTableIOSLinkBlock)block
{
  CGPoint point = [recognizer locationInView:self];
  NSString *url = [self linkAtPoint:point].url;
  if (url && block) {
    block(url);
  }
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
  if (recognizer.state != UIGestureRecognizerStateEnded)
    return;
  CGPoint point = [recognizer locationInView:self];
  if ([[self spoilerCellAtPoint:point] revealAtPoint:point]) {
    [self setNeedsDisplay];
    return;
  }
  ENRMTableIOSItemHit *hit = [self itemAtPoint:point];
  if (!hit)
    return;
  if (hit.kind == ENRMTableIOSItemKindLink) {
    if (self.onLinkTap)
      self.onLinkTap(hit.url);
  } else if (self.onImageTap) {
    self.onImageTap(hit.url, hit.title ?: @"");
  }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
  if (![gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]])
    return YES;
  // Reject before recognition so the context-menu interaction can own this touch.
  NSString *url = [self linkAtPoint:[touch locationInView:self]].url;
  return !(url && self.hasLinkContextMenu && self.hasLinkContextMenu(url));
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
  if (recognizer.state == UIGestureRecognizerStateBegan) {
    [self handleLinkGesture:recognizer block:self.onLinkLongTap];
  }
}

@end

#endif // !TARGET_OS_OSX
