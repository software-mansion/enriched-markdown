#import "ENRMTableGridView.h"
#import "ENRMMenuAction.h"
#import "ENRMTableSpoilerCells.h"

#if TARGET_OS_OSX

@implementation ENRMMacOSTableRowData
@end

@implementation ENRMTableGridView {
  NSArray<ENRMMacOSTableRowData *> *_tableRows;
  NSArray<NSNumber *> *_columnWidths;
  NSArray<NSNumber *> *_rowHeights;
  NSColor *_borderColor;
  CGFloat _borderWidth;
  CGFloat _horizontalCellPadding;
  CGFloat _verticalCellPadding;
  CGFloat _cornerRadius;
  ENRMTableSpoilerCells *_spoilers;
  BOOL _pressedSpoiler;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _spoilers = [[ENRMTableSpoilerCells alloc] initWithHost:self];
  }
  return self;
}

- (BOOL)isFlipped
{
  return YES;
}

- (void)updateWithRows:(NSArray<ENRMMacOSTableRowData *> *)rows
             columnWidths:(NSArray<NSNumber *> *)columnWidths
               rowHeights:(NSArray<NSNumber *> *)rowHeights
              borderColor:(NSColor *)borderColor
              borderWidth:(CGFloat)borderWidth
    horizontalCellPadding:(CGFloat)horizontalCellPadding
      verticalCellPadding:(CGFloat)verticalCellPadding
             cornerRadius:(CGFloat)cornerRadius
{
  _tableRows = rows;
  _columnWidths = columnWidths;
  _rowHeights = rowHeights;
  _borderColor = borderColor;
  _borderWidth = borderWidth;
  _horizontalCellPadding = horizontalCellPadding;
  _verticalCellPadding = verticalCellPadding;
  _cornerRadius = cornerRadius;
  [self syncSpoilerCells];
  [self setNeedsDisplay:YES];
}

#pragma mark - Spoilers

- (void)setSpoilerOverlay:(ENRMSpoilerOverlay)spoilerOverlay
{
  _spoilerOverlay = spoilerOverlay;
  _spoilers.spoilerOverlay = spoilerOverlay;
}

- (void)syncSpoilerCells
{
  NSMutableArray<NSArray<NSAttributedString *> *> *texts = [NSMutableArray arrayWithCapacity:_tableRows.count];
  NSMutableArray<NSColor *> *backgrounds = [NSMutableArray arrayWithCapacity:_tableRows.count];
  for (ENRMMacOSTableRowData *row in _tableRows) {
    [texts addObject:row.cellTexts ?: @[]];
    [backgrounds addObject:row.backgroundColor ?: NSColor.clearColor];
  }
  _spoilers.config = _spoilerConfig;
  [_spoilers syncWithTexts:texts backgrounds:backgrounds];
  NSArray<NSNumber *> *rowTops = ENRMTableOffsets(_rowHeights);
  NSArray<NSNumber *> *columnLefts = ENRMTableOffsets(_columnWidths);
  [_spoilers layoutWithTextRect:^CGRect(NSUInteger r, NSUInteger c, CGRect *cellRect) {
    if (r >= rowTops.count || c >= columnLefts.count)
      return CGRectZero;
    CGFloat y = rowTops[r].doubleValue;
    CGFloat x = columnLefts[c].doubleValue;
    CGFloat inset = self->_borderWidth;
    *cellRect = NSMakeRect(x + inset, y + inset, [self->_columnWidths[c] doubleValue] - inset,
                           [self->_rowHeights[r] doubleValue] - inset);
    return NSMakeRect(x + self->_horizontalCellPadding, y + self->_verticalCellPadding,
                      [self->_columnWidths[c] doubleValue] - self->_horizontalCellPadding * 2,
                      [self->_rowHeights[r] doubleValue] - self->_verticalCellPadding * 2);
  }];
}

- (void)mouseDown:(NSEvent *)event
{
  _pressedSpoiler = [_spoilers hasSpoilerAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
  if (!_pressedSpoiler)
    [super mouseDown:event];
}

- (void)mouseUp:(NSEvent *)event
{
  if (!_pressedSpoiler) {
    [super mouseUp:event];
    return;
  }
  _pressedSpoiler = NO;
  if ([_spoilers revealAtPoint:[self convertPoint:event.locationInWindow fromView:nil]])
    [self setNeedsDisplay:YES];
}

- (NSMenu *)menuForEvent:(NSEvent *)event
{
  return _menuProvider ? _menuProvider() : [super menuForEvent:event];
}

- (void)drawRect:(NSRect)dirtyRect
{
  if (!_tableRows.count || !_columnWidths.count || !_rowHeights.count)
    return;

  [[NSGraphicsContext currentContext] saveGraphicsState];

  NSBezierPath *outline = nil;
  if (_cornerRadius > 0) {
    outline = [NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:_cornerRadius yRadius:_cornerRadius];
    [outline setClip];
  }

  CGFloat yOffset = 0;
  for (NSUInteger r = 0; r < _tableRows.count; r++) {
    ENRMMacOSTableRowData *rowData = _tableRows[r];
    CGFloat rowHeight = [_rowHeights[r] doubleValue];
    CGFloat xOffset = 0;

    for (NSUInteger c = 0; c < rowData.cellTexts.count; c++) {
      CGFloat columnWidth = [_columnWidths[c] doubleValue];
      NSRect cellRect = NSMakeRect(xOffset, yOffset, columnWidth + _borderWidth, rowHeight + _borderWidth);

      [rowData.backgroundColor setFill];
      NSRectFill(cellRect);

      [_borderColor setStroke];
      NSBezierPath *border = [NSBezierPath bezierPathWithRect:cellRect];
      border.lineWidth = _borderWidth;
      [border stroke];

      NSAttributedString *text = rowData.cellTexts[c];
      if (text.length > 0) {
        NSRect textRect = NSMakeRect(xOffset + _horizontalCellPadding, yOffset + _verticalCellPadding,
                                     columnWidth - _horizontalCellPadding * 2, rowHeight - _verticalCellPadding * 2);
        [text drawWithRect:textRect
                   options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
                   context:nil];
      }

      xOffset += columnWidth;
    }
    yOffset += rowHeight;
  }

  // The rounded clip cuts the square cell strokes; draw the arcs.
  if (outline && _borderWidth > 0) {
    [_borderColor setStroke];
    outline.lineWidth = _borderWidth;
    [outline stroke];
  }

  [[NSGraphicsContext currentContext] restoreGraphicsState];
}

@end

#endif // TARGET_OS_OSX
