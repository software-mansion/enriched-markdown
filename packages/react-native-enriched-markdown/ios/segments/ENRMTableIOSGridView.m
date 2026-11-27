#import "ENRMTableIOSGridView.h"
#import "ENRMDroppableContent.h"
#import "LinkTapUtils.h"

#if !TARGET_OS_OSX
#import "MarkdownExtractor.h"
#import "PasteboardUtils.h"
#import "RuntimeKeys.h"
#import "TableContainerView.h"

@interface ENRMTableIOSGridView () <UIGestureRecognizerDelegate>
@end

// Where text sits across its cell: 0 at the left, 0.5 centred, 1 at the right.
static CGFloat ENRMTableTextAnchor(NSAttributedString *text)
{
  NSParagraphStyle *style =
      [text attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:NULL] ?: NSParagraphStyle.defaultParagraphStyle;
  switch (style.alignment) {
    case NSTextAlignmentCenter:
      return 0.5;
    case NSTextAlignmentRight:
      return 1;
    case NSTextAlignmentLeft:
      return 0;
    default:
      return ENRMParagraphIsRTL(style) ? 1 : 0;
  }
}

typedef struct {
  CGRect layoutRect;
  CGRect visibleRect;
} ENRMTableTextGeometry;

// Ticks the row fade without the display link retaining the grid.
@interface ENRMTableFadeTicker : NSObject
@property (nonatomic, weak) ENRMTableIOSGridView *grid;
@end

@interface ENRMTableIOSGridView ()
- (void)stepRowFade:(CADisplayLink *)link;
- (void)drawGridInRect:(CGRect)dirtyRect excludingSelectedText:(BOOL)excludingSelectedText;
@end

@interface ENRMTableGridDrawingView : UIView <ENRMDroppableContent>
@property (nonatomic, weak) ENRMTableIOSGridView *grid;
@property (nonatomic, assign) BOOL drawsSelectionBackdrop;
@end

@implementation ENRMTableGridDrawingView

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    self.opaque = NO;
    self.backgroundColor = UIColor.clearColor;
    self.userInteractionEnabled = NO;
    self.contentMode = UIViewContentModeRedraw;
  }
  return self;
}

- (void)drawRect:(CGRect)dirtyRect
{
  CGPoint origin = self.frame.origin;
  CGContextTranslateCTM(UIGraphicsGetCurrentContext(), -origin.x, -origin.y);
  [self.grid drawGridInRect:CGRectOffset(dirtyRect, origin.x, origin.y)
       excludingSelectedText:self.drawsSelectionBackdrop];
}

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

@implementation ENRMTableCellTextView {
  NSArray<UIMenuItem *> *_legacyCopyItems;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  if (self = [super initWithFrame:frame]) {
    objc_setAssociatedObject(self.textContainer, kTextViewKey, self, OBJC_ASSOCIATION_ASSIGN);
  }
  return self;
}

- (void)dealloc
{
  objc_setAssociatedObject(self.textContainer, kTextViewKey, nil, OBJC_ASSOCIATION_ASSIGN);
}

- (NSArray<UIMenuItem *> *)legacyCopyItems
{
  NSRange range = self.selectedRange;
  ENRMSelectionMenuConfig config = self.legacyMenuConfig();
  NSMutableArray<UIMenuItem *> *items = [NSMutableArray array];
  if (config.copyLabel.length && ![config.copyLabel isEqualToString:@"Copy"]) {
    [items addObject:[[UIMenuItem alloc] initWithTitle:config.copyLabel action:@selector(enrmCopySelectedText:)]];
  }
  if (config.copyAsMarkdown && extractMarkdownFromAttributedString(self.attributedText, range).length) {
    [items addObject:[[UIMenuItem alloc] initWithTitle:config.copyAsMarkdownLabel
                                             action:@selector(enrmCopySelectedMarkdown:)]];
  }
  NSUInteger imageCount = config.copyImageURL ? imageURLsInRange(self.attributedText, range).count : 0;
  if (imageCount) {
    [items addObject:[[UIMenuItem alloc] initWithTitle:ENRMResolveImageURLsTitle(config, imageCount)
                                             action:@selector(enrmCopySelectedImageURLs:)]];
  }
  if (self.table.dynamicProps.enableBlockContextMenu) {
    [items addObjectsFromArray:@[
      [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy Table", nil) action:@selector(enrmCopyTable:)],
      [[UIMenuItem alloc] initWithTitle:NSLocalizedString(@"Copy Table as Markdown", nil)
                               action:@selector(enrmCopyTableAsMarkdown:)]
    ]];
  }
  return items;
}

- (void)refreshLegacyCopyMenu
{
  if (!self.legacyMenuConfig)
    return;
  NSRange range = self.selectedRange;
  NSUInteger length = self.attributedText.length;
  if (!self.isFirstResponder || !range.length || range.location >= length || range.length > length - range.location) {
    [self clearLegacyCopyMenu];
    return;
  }
  _legacyCopyItems = [self legacyCopyItems];
  if (_legacyCopyItems.count)
    ENRMSetLegacyTableMenuItems(self, _legacyCopyItems);
  else
    [self clearLegacyCopyMenu];
}

- (void)clearLegacyCopyMenu
{
  _legacyCopyItems = nil;
  ENRMClearLegacyTableMenuItems(self);
}

- (BOOL)becomeFirstResponder
{
  BOOL became = [super becomeFirstResponder];
  if (became)
    [self refreshLegacyCopyMenu];
  return became;
}

- (BOOL)resignFirstResponder
{
  BOOL resigned = [super resignFirstResponder];
  if (resigned && self.legacyMenuConfig)
    [self clearLegacyCopyMenu];
  return resigned;
}

- (void)didMoveToWindow
{
  [super didMoveToWindow];
  if (!self.window && self.legacyMenuConfig)
    [self clearLegacyCopyMenu];
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender
{
  if (self.legacyMenuConfig && self.isFirstResponder && self.selectedRange.length) {
    for (UIMenuItem *item in _legacyCopyItems) {
      if (item.action == action)
        return YES;
      if (item.action == @selector(enrmCopySelectedText:) && action == @selector(copy:) &&
          ![sender isKindOfClass:UIKeyCommand.class])
        return NO;
    }
  }
  return [super canPerformAction:action withSender:sender];
}

- (void)enrmCopySelectedText:(id)sender
{
  [self copy:sender];
}

- (void)enrmCopySelectedMarkdown:(id)sender
{
  NSRange range = self.selectedRange;
  NSString *markdown = extractMarkdownFromAttributedString(self.attributedText, range);
  if (markdown.length)
    ENRMCopySelectionString(markdown, ENRMSelectionCopyFormatMarkdown, range, self.onLegacyCopy);
}

- (void)enrmCopySelectedImageURLs:(id)sender
{
  NSRange range = self.selectedRange;
  NSArray<NSString *> *urls = imageURLsInRange(self.attributedText, range);
  if (urls.count)
    ENRMCopySelectionString([urls componentsJoinedByString:@"\n"], ENRMSelectionCopyFormatImageURLs, range,
                            self.onLegacyCopy);
}

- (void)enrmCopyTable:(id)sender
{
  [self.table copyTableToPasteboard];
}

- (void)enrmCopyTableAsMarkdown:(id)sender
{
  [self.table copyMarkdownToPasteboard];
}

@end

@implementation ENRMTableIOSGridView {
  ENRMTableGridDrawingView *_drawingView;
  ENRMTableGridDrawingView *_selectionBackdrop;
  NSArray<ENRMTableIOSRowData *> *_tableRows;
  NSArray<NSNumber *> *_columnWidths;
  NSArray<NSNumber *> *_rowHeights;
  NSAttributedString *_selectedText;
  uint64_t _selectedCellSignature;
  CGRect _selectionDrawRect;
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
    self.opaque = NO;
    self.accessibilityElementsHidden = YES;

    _drawingView = [[ENRMTableGridDrawingView alloc] initWithFrame:self.bounds];
    _drawingView.grid = self;
    _drawingView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_drawingView];

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

- (void)setNeedsDisplay
{
  [_drawingView setNeedsDisplay];
  [_selectionBackdrop setNeedsDisplay];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  [self updateSelectionBackdrop];
}

- (NSArray<NSNumber *> *)displayedColumnWidths
{
  return _shownColumnWidths.count == _columnWidths.count ? _shownColumnWidths : _columnWidths;
}

- (ENRMTableTextGeometry)geometryForText:(NSAttributedString *)text column:(NSUInteger)column cellRect:(CGRect)cellRect
{
  CGFloat finalWidth = _columnWidths[column].doubleValue;
  CGFloat shownWidth = cellRect.size.width;
  // Keep the final wrapping while the displayed column grows towards it.
  CGFloat shift = shownWidth == finalWidth ? 0 : (shownWidth - finalWidth) * ENRMTableTextAnchor(text);
  CGRect layoutRect = CGRectInset(CGRectMake(cellRect.origin.x + shift, cellRect.origin.y, finalWidth,
                                            cellRect.size.height),
                                  _horizontalCellPadding, _verticalCellPadding);
  CGRect visibleRect = layoutRect;
  if (_shownColumnWidths.count == _columnWidths.count) {
    CGRect clip = CGRectMake(CGRectGetMinX(cellRect) + _borderWidth, CGRectGetMinY(cellRect) + _borderWidth,
                             shownWidth - _borderWidth, cellRect.size.height - _borderWidth);
    visibleRect = CGRectIntersection(layoutRect, clip);
  }
  return (ENRMTableTextGeometry){layoutRect, visibleRect};
}

- (void)drawGridInRect:(CGRect)dirtyRect excludingSelectedText:(BOOL)excludingSelectedText
{
  if (!_tableRows.count || !_columnWidths.count || !_rowHeights.count)
    return;

  NSArray<NSNumber *> *shownWidths = [self displayedColumnWidths];
  // Cell strokes can extend beyond their layout bounds.
  CGRect dirtyCells = CGRectInset(dirtyRect, -1.5 * _borderWidth, -1.5 * _borderWidth);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CFTimeInterval now = CACurrentMediaTime();
  CGFloat yOffset = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    ENRMTableIOSRowData *rowData = _tableRows[r];
    CGFloat rowHeight = [_rowHeights[r] doubleValue];
    if (yOffset >= CGRectGetMaxY(dirtyCells))
      break;
    if (yOffset + rowHeight <= CGRectGetMinY(dirtyCells)) {
      yOffset += rowHeight;
      continue;
    }
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
      if (xOffset >= CGRectGetMaxX(dirtyCells))
        break;
      CGRect cellRect = CGRectMake(xOffset, yOffset, columnWidth, rowHeight);
      xOffset += columnWidth;
      if (xOffset <= CGRectGetMinX(dirtyCells))
        continue;
      CGRect borderRect = CGRectMake(cellRect.origin.x, cellRect.origin.y, columnWidth + _borderWidth,
                                     rowHeight + _borderWidth);

      [rowData.backgroundColor setFill];
      UIRectFill(borderRect);

      [_borderColor setStroke];
      UIBezierPath *border = [UIBezierPath bezierPathWithRect:borderRect];
      border.lineWidth = _borderWidth;
      [border stroke];

      NSAttributedString *text = rowData.cellTexts[c];
      if (text.length > 0 && !(excludingSelectedText && r == _selectedRow && c == _selectedColumn)) {
        ENRMTableTextGeometry geometry = [self geometryForText:text column:c cellRect:cellRect];
        if (CGRectIsEmpty(geometry.visibleRect))
          continue;
        BOOL clipped = !CGRectEqualToRect(geometry.layoutRect, geometry.visibleRect);
        if (clipped) {
          CGContextSaveGState(context);
          CGContextClipToRect(context, geometry.visibleRect);
        }
        [text drawWithRect:geometry.layoutRect
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                   context:nil];
        if (clipped) {
          CGContextRestoreGState(context);
        }
      }
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
- (BOOL)cellAtPoint:(CGPoint)point row:(NSUInteger *)row column:(NSUInteger *)column cellRect:(CGRect *)rect
{
  NSArray<NSNumber *> *widths = [self displayedColumnWidths];
  CGFloat y = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    CGFloat height = _rowHeights[r].doubleValue;
    if (point.y >= y && point.y < y + height) {
      CGFloat x = 0;
      NSUInteger count = MIN(widths.count, _tableRows[r].cellTexts.count);
      for (NSUInteger c = 0; c < count; c++) {
        CGFloat width = widths[c].doubleValue;
        if (point.x >= x && point.x < x + width) {
          *row = r;
          *column = c;
          *rect = CGRectMake(x, y, width, height);
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

static ENRMTableIOSItemHit *itemInAttributedString(NSAttributedString *text, ENRMTableTextGeometry geometry,
                                                 CGPoint point, BOOL allowsNearestLink)
{
  if (text.length == 0 || !CGRectContainsPoint(geometry.visibleRect, point))
    return nil;

  CGRect textRect = geometry.layoutRect;
  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:textRect.size];
  textContainer.lineFragmentPadding = 0;
  [layoutManager addTextContainer:textContainer];
  [textStorage addLayoutManager:layoutManager];
  [layoutManager ensureLayoutForTextContainer:textContainer];

  CGPoint local = CGPointMake(point.x - textRect.origin.x, point.y - textRect.origin.y);
  NSUInteger glyphIndex = [layoutManager glyphIndexForPoint:local
                                            inTextContainer:textContainer
                             fractionOfDistanceThroughGlyph:NULL];
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
  if (!imageURL && (!linkURL || !allowsNearestLink)) {
    // A hold in unused space must reach the block menu, including in a cell ending in a link.
    CGRect glyphRect = [layoutManager boundingRectForGlyphRange:NSMakeRange(glyphIndex, 1)
                                                 inTextContainer:textContainer];
    if (!CGRectContainsPoint(glyphRect, local) ||
        [NSCharacterSet.newlineCharacterSet characterIsMember:[text.string characterAtIndex:charIndex]])
      return nil;
  }
  if (!linkURL && !imageURL) {
    ENRMTableIOSItemHit *hit = [[ENRMTableIOSItemHit alloc] init];
    hit.kind = ENRMTableIOSItemKindText;
    return hit;
  }

  NSRange glyphRange = [layoutManager glyphRangeForCharacterRange:itemRange actualCharacterRange:NULL];
  CGRect frame = [layoutManager boundingRectForGlyphRange:glyphRange inTextContainer:textContainer];
  // An image also needs the tap inside its attachment bounds.
  if (imageURL && !CGRectContainsPoint(frame, local))
    return nil;

  frame = CGRectOffset(frame, textRect.origin.x, textRect.origin.y);
  if (!CGRectEqualToRect(geometry.layoutRect, geometry.visibleRect)) {
    frame = CGRectIntersection(frame, geometry.visibleRect);
    if (CGRectIsEmpty(frame))
      return nil;
  }
  ENRMTableIOSItemHit *hit = [[ENRMTableIOSItemHit alloc] init];
  hit.kind = linkURL ? ENRMTableIOSItemKindLink : ENRMTableIOSItemKindImage;
  hit.url = linkURL ?: imageURL;
  hit.title = linkURL ? linkTitleAtIndex(text, charIndex)
                      : [text attribute:@"imageAltText" atIndex:charIndex effectiveRange:NULL];
  hit.frame = frame;
  return hit;
}

- (ENRMTableIOSItemHit *)itemAtPoint:(CGPoint)point allowsNearestLink:(BOOL)allowsNearestLink
{
  NSUInteger row, column;
  CGRect rect;
  if (![self cellAtPoint:point row:&row column:&column cellRect:&rect])
    return nil;
  NSAttributedString *text = _tableRows[row].cellTexts[column];
  if (text.length == 0)
    return nil;
  return itemInAttributedString(text, [self geometryForText:text column:column cellRect:rect], point, allowsNearestLink);
}

- (BOOL)ownsCellInteractionAtPoint:(CGPoint)point
{
  ENRMTableIOSItemHit *hit = [self itemAtPoint:point allowsNearestLink:NO];
  return hit &&
         (hit.kind == ENRMTableIOSItemKindText
              ? self.table.dynamicProps.tableSelectionHost.tableSelectionEnabled
              : hit.kind == ENRMTableIOSItemKindLink && self.hasLinkContextMenu && self.hasLinkContextMenu(hit.url));
}

- (ENRMTableIOSItemHit *)linkAtPoint:(CGPoint)point
{
  ENRMTableIOSItemHit *hit = [self itemAtPoint:point allowsNearestLink:NO];
  return hit.kind == ENRMTableIOSItemKindLink ? hit : nil;
}

#pragma mark - Native selection in the touched cell

- (void)clearSelectionView
{
  if (self.table.dynamicProps.activeSelectionGrid == self)
    self.table.dynamicProps.activeSelectionGrid = nil;
  if (!_selectionView)
    return;
  [_selectionView resignFirstResponder];
  [_selectionView removeFromSuperview];
  _selectionView = nil;
  _selectedText = nil;
  [_selectionBackdrop removeFromSuperview];
  _selectionBackdrop = nil;
  _drawingView.layer.mask = nil;
}

- (void)updateSelectionBackdrop
{
  if (!_selectionView)
    return;
  // UIKit can redraw the entire backing store after a partial invalidation.
  // Cut out the selected text's region and paint its cell background separately.
  // A cutout preserves translucent row colors and text anti-aliasing.
  CGRect cover = CGRectIntersection(self.bounds, CGRectIntegral(CGRectInset(_selectionDrawRect, -1, -1)));
  if (CGRectIsEmpty(cover)) {
    _selectionBackdrop.hidden = YES;
    _drawingView.layer.mask = nil;
    return;
  }
  CAShapeLayer *mask = (CAShapeLayer *)_drawingView.layer.mask;
  if (mask && CGRectEqualToRect(mask.frame, _drawingView.bounds) && CGRectEqualToRect(cover, _selectionBackdrop.frame))
    return;
  if (!_selectionBackdrop) {
    _selectionBackdrop = [[ENRMTableGridDrawingView alloc] initWithFrame:cover];
    _selectionBackdrop.grid = self;
    _selectionBackdrop.drawsSelectionBackdrop = YES;
    [self insertSubview:_selectionBackdrop belowSubview:_selectionView];
  }
  _selectionBackdrop.hidden = NO;
  _selectionBackdrop.frame = cover;
  [_selectionBackdrop setNeedsDisplay];
  UIBezierPath *path = [UIBezierPath bezierPathWithRect:_drawingView.bounds];
  [path appendPath:[UIBezierPath bezierPathWithRect:cover]];
  if (!mask) {
    mask = [CAShapeLayer layer];
    mask.fillRule = kCAFillRuleEvenOdd;
  }
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  mask.frame = _drawingView.bounds;
  mask.path = path.CGPath;
  _drawingView.layer.mask = mask;
  [CATransaction commit];
}

- (void)layoutSelectionViewWithGeometry:(ENRMTableTextGeometry)geometry
{
  _selectionView.frame = geometry.layoutRect;
  _selectionDrawRect = geometry.visibleRect;
  if (CGRectEqualToRect(geometry.layoutRect, geometry.visibleRect)) {
    _selectionView.maskView = nil;
  } else {
    UIView *mask = _selectionView.maskView;
    if (!mask) {
      mask = [UIView new];
      mask.backgroundColor = UIColor.blackColor;
      _selectionView.maskView = mask;
    }
    mask.frame = CGRectIsEmpty(geometry.visibleRect)
        ? CGRectZero
        : [_selectionView convertRect:geometry.visibleRect fromView:self];
  }
  [_selectionView setDrawnRect:_selectionView.bounds];
  [self updateSelectionBackdrop];
}

- (uint64_t)cellSignatureAtRow:(NSUInteger)row column:(NSUInteger)column
{
  NSArray<NSNumber *> *signatures = _tableRows[row].cellSignatures;
  return column < signatures.count ? signatures[column].unsignedLongLongValue : 0;
}

- (void)updateSelectionView
{
  if (!_selectionView)
    return;
  if (_selectedRow >= _tableRows.count || _selectedColumn >= _columnWidths.count ||
      _selectedColumn >= _tableRows[_selectedRow].cellTexts.count) {
    [self clearSelectionView];
    return;
  }
  NSAttributedString *text = _tableRows[_selectedRow].cellTexts[_selectedColumn];
  uint64_t signature = [self cellSignatureAtRow:_selectedRow column:_selectedColumn];
  if (![_selectedText isEqualToAttributedString:text]) {
    if (!signature || signature != _selectedCellSignature || ![_selectedText.string isEqualToString:text.string]) {
      [self clearSelectionView];
      return;
    }
    // Re-rendering an unchanged source cell can create fresh attachment objects. Update the
    // editor's attributes in place so the native selection stays in the same text storage.
    NSTextStorage *storage = _selectionView.textStorage;
    [storage beginEditing];
    [text enumerateAttributesInRange:NSMakeRange(0, text.length)
                             options:0
                          usingBlock:^(NSDictionary *attributes, NSRange range, BOOL *stop) {
                            [storage setAttributes:attributes range:range];
                          }];
    [storage endEditing];
  }
  _selectedText = text;
  _selectedCellSignature = signature;
  CGFloat x = 0, y = 0;
  NSArray<NSNumber *> *widths = [self displayedColumnWidths];
  for (NSUInteger c = 0; c < _selectedColumn; c++)
    x += widths[c].doubleValue;
  for (NSUInteger r = 0; r < _selectedRow; r++)
    y += _rowHeights[r].doubleValue;
  CGRect rect = CGRectMake(x, y, widths[_selectedColumn].doubleValue, _rowHeights[_selectedRow].doubleValue);
  [self layoutSelectionViewWithGeometry:[self geometryForText:_selectedText column:_selectedColumn cellRect:rect]];
}

// A native grabber can extend into the blank space below or above its cell.
static BOOL ENRMTableHitsGrabber(CGPoint point, CGRect caret, CGFloat grabberY, UIView *editor)
{
  CGFloat x = CGRectGetMidX(caret);
  if (editor.maskView) {
    CGRect clip = editor.maskView.frame;
    CGRect bounds = editor.bounds;
    // Do not constrain the touch vertically. Visible grabbers can extend above or below the clip.
    if (CGRectIsEmpty(clip) ||
        (CGRectGetMinX(clip) > CGRectGetMinX(bounds) && MIN(x, point.x) < CGRectGetMinX(clip)) ||
        (CGRectGetMaxX(clip) < CGRectGetMaxX(bounds) && MAX(x, point.x) > CGRectGetMaxX(clip)) ||
        (CGRectGetMinY(clip) > CGRectGetMinY(bounds) && CGRectGetMaxY(caret) <= CGRectGetMinY(clip)) ||
        (CGRectGetMaxY(clip) < CGRectGetMaxY(bounds) && CGRectGetMinY(caret) >= CGRectGetMaxY(clip)))
      return NO;
  }
  return hypot(point.x - x, point.y - grabberY) <= 8;
}

- (BOOL)isSelectionHandleAtPoint:(CGPoint)point
{
  UITextRange *range = _selectionView.selectedTextRange;
  if (!_selectionView.isFirstResponder || !range || range.isEmpty)
    return NO;
  CGPoint local = [self convertPoint:point toView:_selectionView];
  CGRect start = [_selectionView caretRectForPosition:range.start];
  CGRect end = [_selectionView caretRectForPosition:range.end];
  return ENRMTableHitsGrabber(local, start, CGRectGetMinY(start) - 5, _selectionView) ||
         ENRMTableHitsGrabber(local, end, CGRectGetMaxY(end) + 5, _selectionView);
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
  UIView *hit = [super hitTest:point withEvent:event];
  id<ENRMTableSelectionHost> host = self.table.dynamicProps.tableSelectionHost;
  if (!hit || !event || event.type != UIEventTypeTouches || !host.tableSelectionEnabled)
    return hit;

  if ([self isSelectionHandleAtPoint:point])
    return [hit isDescendantOfView:_selectionView] ? hit : _selectionView;
  NSUInteger row, column;
  CGRect rect;
  if (![self cellAtPoint:point row:&row column:&column cellRect:&rect])
    return self;
  NSAttributedString *text = _tableRows[row].cellTexts[column];
  if (text.length == 0)
    return self;
  ENRMTableTextGeometry geometry = [self geometryForText:text column:column cellRect:rect];
  if (itemInAttributedString(text, geometry, point, NO).kind != ENRMTableIOSItemKindText)
    return self;
  if (!_selectionView || row != _selectedRow || column != _selectedColumn) {
    [self.table.dynamicProps.activeSelectionGrid clearSelectionView];
    self.table.dynamicProps.activeSelectionGrid = self;
    _selectedRow = row;
    _selectedColumn = column;
    _selectionView = [[ENRMTableCellTextView alloc] initWithFrame:geometry.layoutRect];
    _selectionView.table = self.table;
    _selectionView.editable = NO;
    _selectionView.textDragInteraction.enabled = NO;
    _selectionView.selectable = YES;
    _selectionView.scrollEnabled = NO;
    _selectionView.backgroundColor = UIColor.clearColor;
    _selectionView.textContainerInset = UIEdgeInsetsZero;
    _selectionView.textContainer.lineFragmentPadding = 0;
    _selectedText = text;
    _selectedCellSignature = [self cellSignatureAtRow:row column:column];
    _selectionView.attributedText = text;
    [host configureTableSelectionView:_selectionView];
    [self addSubview:_selectionView];
    [self layoutSelectionViewWithGeometry:geometry];
  }
  return [super hitTest:point withEvent:event];
}

#pragma mark - Gesture handlers

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
  if (recognizer.state != UIGestureRecognizerStateEnded)
    return;
  ENRMTableIOSItemHit *hit = [self itemAtPoint:[recognizer locationInView:self] allowsNearestLink:YES];
  if (!hit)
    return;
  if (hit.kind == ENRMTableIOSItemKindLink) {
    if (self.onLinkTap)
      self.onLinkTap(hit.url);
  } else if (hit.kind == ENRMTableIOSItemKindImage && self.onImageTap) {
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
    CGPoint point = [recognizer locationInView:self];
    NSString *url = [self linkAtPoint:point].url;
    if (url && self.onLinkLongTap)
      self.onLinkLongTap(url);
    else
      [self.table showTableMenuAtPoint:point];
  }
}

@end

#endif // !TARGET_OS_OSX
