#import "ENRMTableIOSGridView.h"

#if !TARGET_OS_OSX

@implementation ENRMTableIOSRowData
@end

@implementation ENRMTableIOSGridView {
  NSArray<ENRMTableIOSRowData *> *_tableRows;
  NSArray<NSNumber *> *_columnWidths;
  NSArray<NSNumber *> *_rowHeights;
  UIColor *_borderColor;
  CGFloat _borderWidth;
  CGFloat _horizontalCellPadding;
  CGFloat _verticalCellPadding;
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
  _horizontalCellPadding = horizontalCellPadding;
  _verticalCellPadding = verticalCellPadding;
  [self setNeedsDisplay];
}

- (void)fadeInRowsFrom:(NSUInteger)startRow duration:(NSTimeInterval)duration
{
  if (startRow >= _tableRows.count)
    return;

  [UIView transitionWithView:self
                    duration:duration
                     options:UIViewAnimationOptionTransitionCrossDissolve
                  animations:^{}
                  completion:nil];
}

#pragma mark - Drawing

- (void)drawRect:(CGRect)dirtyRect
{
  if (!_tableRows.count || !_columnWidths.count || !_rowHeights.count)
    return;

  CGFloat yOffset = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    ENRMTableIOSRowData *rowData = _tableRows[r];
    CGFloat rowHeight = [_rowHeights[r] doubleValue];
    CGFloat xOffset = 0;

    NSUInteger colCount = MIN(rowData.cellTexts.count, _columnWidths.count);
    for (NSUInteger c = 0; c < colCount; c++) {
      CGFloat columnWidth = [_columnWidths[c] doubleValue];
      CGRect cellRect = CGRectMake(xOffset, yOffset, columnWidth + _borderWidth, rowHeight + _borderWidth);

      [rowData.backgroundColor setFill];
      UIRectFill(cellRect);

      [_borderColor setStroke];
      UIBezierPath *border = [UIBezierPath bezierPathWithRect:cellRect];
      border.lineWidth = _borderWidth;
      [border stroke];

      NSAttributedString *text = rowData.cellTexts[c];
      if (text.length > 0) {
        CGRect textRect = CGRectMake(xOffset + _horizontalCellPadding, yOffset + _verticalCellPadding,
                                     columnWidth - _horizontalCellPadding * 2, rowHeight - _verticalCellPadding * 2);
        [text drawWithRect:textRect
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                   context:nil];
      }

      xOffset += columnWidth;
    }
    yOffset += rowHeight;
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

static NSString *linkInAttributedString(NSAttributedString *text, CGRect textRect, CGPoint point)
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

  return [text attribute:@"linkURL" atIndex:charIndex effectiveRange:NULL];
}

- (NSString *)linkURLAtPoint:(CGPoint)point
{
  CGFloat rowY, rowH, colX, colW;
  NSAttributedString *text;
  if (![self cellAtPoint:point rowOrigin:&rowY rowHeight:&rowH colOrigin:&colX colWidth:&colW cellText:&text])
    return nil;

  CGRect textRect = CGRectMake(colX + _horizontalCellPadding, rowY + _verticalCellPadding,
                               colW - _horizontalCellPadding * 2, rowH - _verticalCellPadding * 2);
  if (!CGRectContainsPoint(textRect, point))
    return nil;

  return linkInAttributedString(text, textRect, point);
}

#pragma mark - Gesture handlers

- (void)handleLinkGesture:(UIGestureRecognizer *)recognizer block:(ENRMTableIOSLinkBlock)block
{
  CGPoint point = [recognizer locationInView:self];
  NSString *url = [self linkURLAtPoint:point];
  if (url && block) {
    block(url);
  }
}

- (void)handleTap:(UITapGestureRecognizer *)recognizer
{
  if (recognizer.state == UIGestureRecognizerStateEnded) {
    [self handleLinkGesture:recognizer block:self.onLinkTap];
  }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
  if (recognizer.state == UIGestureRecognizerStateBegan) {
    [self handleLinkGesture:recognizer block:self.onLinkLongTap];
  }
}

@end

#endif // !TARGET_OS_OSX
