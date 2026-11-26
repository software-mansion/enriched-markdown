#import "ENRMTableIOSGridView.h"
#import "ENRMDroppableContent.h"
#import "LinkTapUtils.h"

#if !TARGET_OS_OSX
#import "ENRMMarkdownTextView.h"
#import "TableContainerView.h"

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
  ENRMMarkdownTextView *_selectionView;
  NSAttributedString *_selectedText;
  NSUInteger _selectedRow;
  NSUInteger _selectedColumn;
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
    tap.delegate = self;
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
  [self updateSelectionView];
  [self setNeedsDisplay];
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
  [self updateSelectionView];
  [self setNeedsDisplay];
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
      if (text.length > 0 && !(_selectionView && r == _selectedRow && c == _selectedColumn)) {
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

// Use the displayed cell bounds for hit testing while streamed columns widen.
- (BOOL)cellAtPoint:(CGPoint)point row:(NSUInteger *)row column:(NSUInteger *)column textRect:(CGRect *)rect
{
  NSArray<NSNumber *> *widths = _shownColumnWidths ?: _columnWidths;
  CGFloat y = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    CGFloat height = _rowHeights[r].doubleValue;
    if (point.y >= y && point.y < y + height) {
      CGFloat x = 0;
      for (NSUInteger c = 0; c < _tableRows[r].cellTexts.count; c++) {
        CGFloat width = widths[c].doubleValue;
        if (point.x >= x && point.x < x + width) {
          *row = r;
          *column = c;
          *rect = CGRectInset(CGRectMake(x, y, width, height), _horizontalCellPadding, _verticalCellPadding);
          return YES;
        }
        x += width;
      }
      return NO;
    }
    y += height;
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
  NSUInteger row, column;
  CGRect rect;
  if (![self cellAtPoint:point row:&row column:&column textRect:&rect] || !CGRectContainsPoint(rect, point))
    return nil;
  return itemInAttributedString(_tableRows[row].cellTexts[column], rect, point);
}

- (ENRMTableIOSItemHit *)linkAtPoint:(CGPoint)point
{
  ENRMTableIOSItemHit *hit = [self itemAtPoint:point];
  return hit.kind == ENRMTableIOSItemKindLink ? hit : nil;
}

#pragma mark - Native selection in the touched cell

- (void)clearSelectionView
{
  [_selectionView removeFromSuperview];
  _selectionView = nil;
  _selectedText = nil;
  [self setNeedsDisplay];
}

- (void)updateSelectionView
{
  if (!_selectionView)
    return;
  if (_selectedRow >= _tableRows.count || _selectedColumn >= _tableRows[_selectedRow].cellTexts.count ||
      ![_selectedText isEqualToAttributedString:_tableRows[_selectedRow].cellTexts[_selectedColumn]]) {
    [self clearSelectionView];
    return;
  }
  CGFloat x = 0, y = 0;
  NSArray<NSNumber *> *widths = _shownColumnWidths ?: _columnWidths;
  for (NSUInteger c = 0; c < _selectedColumn; c++)
    x += widths[c].doubleValue;
  for (NSUInteger r = 0; r < _selectedRow; r++)
    y += _rowHeights[r].doubleValue;
  _selectionView.frame = CGRectInset(CGRectMake(x, y, widths[_selectedColumn].doubleValue, _rowHeights[_selectedRow].doubleValue),
                                     _horizontalCellPadding, _verticalCellPadding);
  [_selectionView setDrawnRect:_selectionView.bounds];
}

static BOOL canSelectCellText(NSAttributedString *text, CGRect rect, CGPoint point)
{
  return text.length && CGRectContainsPoint(rect, point) && !itemInAttributedString(text, rect, point);
}

- (BOOL)isSelectingCellAtPoint:(CGPoint)point
{
  return self.table.dynamicProps.tableSelectionHost.tableSelectionEnabled && _selectionView &&
         canSelectCellText(_selectedText, _selectionView.frame, point);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  UIView *hit = [super hitTest:point withEvent:event];
  id<ENRMTableSelectionHost> host = self.table.dynamicProps.tableSelectionHost;
  if (!hit || !event || event.type != UIEventTypeTouches || !host.tableSelectionEnabled)
    return hit;

  NSUInteger row, column;
  CGRect rect;
  if (![self cellAtPoint:point row:&row column:&column textRect:&rect] || !CGRectContainsPoint(rect, point))
    return hit;
  NSAttributedString *text = _tableRows[row].cellTexts[column];
  if (!canSelectCellText(text, rect, point))
    return self;
  if (!_selectionView || row != _selectedRow || column != _selectedColumn) {
    [self clearSelectionView];
    _selectedRow = row;
    _selectedColumn = column;
    _selectionView = [[ENRMMarkdownTextView alloc] initWithFrame:rect];
    _selectionView.editable = NO;
    _selectionView.selectable = YES;
    _selectionView.scrollEnabled = NO;
    _selectionView.backgroundColor = UIColor.clearColor;
    _selectionView.textContainerInset = UIEdgeInsetsZero;
    _selectionView.textContainer.lineFragmentPadding = 0;
    _selectedText = text;
    _selectionView.attributedText = text;
    [host configureTableSelectionView:_selectionView];
    [self addSubview:_selectionView];
    [_selectionView setDrawnRect:_selectionView.bounds];
    [self setNeedsDisplay];
  }
  return [super hitTest:point withEvent:event];
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
  ENRMTableIOSItemHit *hit = [self itemAtPoint:[recognizer locationInView:self]];
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
  if (_selectionView && [touch.view isDescendantOfView:_selectionView])
    return NO;
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
