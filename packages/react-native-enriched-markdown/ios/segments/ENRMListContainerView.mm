#import "ENRMListContainerView.h"
#import "ENRMBlockquoteContainerView.h"
#import "ENRMDroppableContent.h"
#import "ENRMSegmentHeightMeasurer.h"
#import "ENRMTableIOSGridView.h"
#import "ENRMTextInteractionUtils.h"
#import "EnrichedMarkdownInternalText.h"
#import "LinkTapUtils.h"
#import "ListItemRenderer.h"
#import "ListMarkerDrawer.h"
#import "MarkdownASTNode.h"
#import "MarkdownASTSerializer.h"
#import "ParagraphStyleUtils.h"
#import "PasteboardUtils.h"
#import "SegmentRenderer.h"
#import "TableContainerView.h"

static NSArray<ENRMListMarkerDescriptor *> *ENRMListMarkers(ENRMListSegment *segment, StyleConfig *config)
{
  BOOL ordered = segment.node.type == MarkdownNodeTypeOrderedList;
  NSInteger number = ordered ? MAX(0, [segment.node.attributes[@"start"] ?: @"1" integerValue]) : 1;
  CGFloat defaultWidth = [config effectiveListMarginLeftForNumber:99];
  CGFloat orderedWidth = defaultWidth;
  NSInteger position = number;
  for (MarkdownASTNode *item in segment.node.children) {
    if (item.type != MarkdownNodeTypeListItem)
      continue;
    if (ordered && ![item.attributes[@"isTask"] isEqualToString:@"true"])
      orderedWidth = MAX(orderedWidth, [config effectiveListMarginLeftForNumber:position]);
    position++;
  }
  CGFloat extra = ordered ? orderedWidth - defaultWidth : 0;
  NSMutableArray *markers = [NSMutableArray array];
  NSInteger taskIndex = segment.taskIndexOffset;
  for (MarkdownASTNode *item in segment.node.children) {
    if (item.type != MarkdownNodeTypeListItem)
      continue;
    ENRMListMarkerDescriptor *marker = [ENRMListMarkerDescriptor new];
    marker.listType = ordered ? ListTypeOrdered : ListTypeUnordered;
    marker.number = number++;
    marker.depth = segment.depth;
    marker.isTask = [item.attributes[@"isTask"] isEqualToString:@"true"];
    marker.isChecked = [item.attributes[@"taskChecked"] isEqualToString:@"true"];
    marker.taskIndex = taskIndex;
    taskIndex += ENRMCountTaskItems(item);
    CGFloat markerWidth = marker.isTask ? config.effectiveListMarginLeftForTask + extra
                                        : (ordered ? orderedWidth : config.effectiveListMarginLeftForBullet);
    marker.indent = markerWidth + config.effectiveListGapWidth;
    if (segment.depth > 0)
      marker.indent += config.listStyleMarginLeft - segment.parentMarkerWidth - config.effectiveListGapWidth;
    marker.indent = MAX(0, ceil(marker.indent));
    [markers addObject:marker];
  }
  return markers;
}

static BOOL ENRMListItemIsRTL(MarkdownASTNode *item, ENRMListSegment *segment)
{
  if (segment.writingDirectionMode == ENRMWritingDirectionModeLTR)
    return NO;
  if (segment.writingDirectionMode == ENRMWritingDirectionModeRTL)
    return YES;
  NSWritingDirection direction = segment.writingDirectionMode == ENRMWritingDirectionModeAuto
                                     ? segment.resolvedLayoutDirection
                                     : ENRMFirstStrongDirection(plainTextFromASTNode(item));
  if (direction == NSWritingDirectionNatural)
    direction = segment.resolvedLayoutDirection;
  return direction == NSWritingDirectionRightToLeft ||
         (direction == NSWritingDirectionNatural && ENRMParagraphIsRTL(nil));
}

@interface ENRMListTaskTarget : RCTUIView
@property (nonatomic, copy) void (^activate)(void);
@property (nonatomic, copy) BOOL (^canActivate)(void);
@property (nonatomic, assign) BOOL checked;
@end
@implementation ENRMListTaskTarget
#if !TARGET_OS_OSX
- (BOOL)accessibilityActivate
{
  if (!self.canActivate || !self.canActivate())
    return NO;
  if (self.activate)
    self.activate();
  return YES;
}
- (UIAccessibilityTraits)accessibilityTraits
{
  UIAccessibilityTraits traits = UIAccessibilityTraitButton;
  if (@available(iOS 17.0, *))
    traits |= UIAccessibilityTraitToggleButton;
  if (self.checked)
    traits |= UIAccessibilityTraitSelected;
  if (!self.canActivate || !self.canActivate())
    traits |= UIAccessibilityTraitNotEnabled;
  return traits;
}
#endif
@end

@interface ENRMListItemView : ENRMContainerNodeView
#if !TARGET_OS_OSX
                              <ENRMDroppableContent>
#endif
@property (nonatomic, strong) ENRMListMarkerDescriptor *marker;
@property (nonatomic, strong) ListMarkerDrawer *markerDrawer;
@property (nonatomic, strong) ENRMListTaskTarget *taskTarget;
@property (nonatomic, assign) BOOL rightToLeft;
@end

// Grid tables draw without UITextViews; their first row still provides the
// baseline used for a table-first item's marker and checkbox hit target.
static CGFloat ENRMFirstContentBaseline(RCTUIView *view, StyleConfig *config)
{
  if ([view isKindOfClass:[EnrichedMarkdownInternalText class]]) {
    ENRMPlatformTextView *text = ((EnrichedMarkdownInternalText *)view).textView;
    NSLayoutManager *manager = text.layoutManager;
    [manager ensureLayoutForTextContainer:text.textContainer];
    if (manager.numberOfGlyphs > 0) {
      CGRect line = [manager lineFragmentRectForGlyphAtIndex:0 effectiveRange:NULL];
      CGPoint glyph = [manager locationForGlyphAtIndex:0];
      NSUInteger character = [manager characterIndexForGlyphAtIndex:0];
      NSTextAttachment *attachment = [text.textStorage attribute:NSAttachmentAttributeName
                                                         atIndex:character
                                                  effectiveRange:NULL];
      // TextKit anchors attachments at their bottom edge. Match ListMarkerDrawer's
      // correction so an attachment-first item keeps its marker on the text baseline.
      if ([attachment isKindOfClass:[NSTextAttachment class]]) {
        glyph.y += [attachment attachmentBoundsForTextContainer:text.textContainer
                                           proposedLineFragment:line
                                                  glyphPosition:glyph
                                                 characterIndex:character]
                       .origin.y;
      }
#if !TARGET_OS_OSX
      return text.frame.origin.y + text.textContainerInset.top + line.origin.y + glyph.y;
#else
      return text.frame.origin.y + text.textContainerInset.height + line.origin.y + glyph.y;
#endif
    }
  }
  if ([view isKindOfClass:[TableContainerView class]])
    return config.tableBorderWidth + config.tableCellPaddingVertical + config.tableHeaderFont.ascender;
  for (RCTUIView *child in view.subviews) {
    CGFloat baseline = ENRMFirstContentBaseline(child, config);
    if (baseline >= 0)
      return child.frame.origin.y + baseline;
  }
  return -1;
}

@implementation ENRMListItemView
- (CGFloat)markerBaseline
{
  for (RCTUIView *view in self.segmentViews) {
    CGFloat baseline = ENRMFirstContentBaseline(view, self.config);
    if (baseline >= 0)
      return view.frame.origin.y + baseline;
  }
  return self.config.listStyleFont.ascender;
}
- (CGFloat)markerBoundary
{
  CGFloat bodyEdge = self.rightToLeft ? self.bounds.size.width - self.contentInsets.right : self.contentInsets.left;
  return bodyEdge + (self.rightToLeft ? self.config.effectiveListGapWidth : -self.config.effectiveListGapWidth);
}
- (void)layoutTaskTarget
{
  CGFloat size = self.config.taskListCheckboxSize;
  CGFloat boundary = [self markerBoundary];
  CGFloat center = boundary + (self.rightToLeft ? size / 2 : -size / 2);
  CGFloat baseline = [self markerBaseline];
  CGFloat centerY = baseline - self.config.listStyleFont.capHeight / 2;
  self.taskTarget.frame = CGRectMake(center - size / 2, centerY - MAX(24, size) / 2, size, MAX(24, size));
#if !TARGET_OS_OSX
  [self setNeedsDisplay];
#else
  self.needsDisplay = YES;
#endif
}
#if !TARGET_OS_OSX
- (void)layoutSubviews
{
  [super layoutSubviews];
  [self layoutTaskTarget];
}
- (NSArray *)accessibilityElements
{
  NSArray *body = [super accessibilityElements];
  return self.marker.isTask ? [@[ self.taskTarget ] arrayByAddingObjectsFromArray:body] : body;
}
#else
- (void)layout
{
  [super layout];
  [self layoutTaskTarget];
}
#endif
- (void)drawRect:(CGRect)rect
{
  [self.markerDrawer drawMarker:self.marker
                      boundaryX:[self markerBoundary]
                      baselineY:[self markerBaseline]
                           font:self.config.listStyleFont
                          isRTL:self.rightToLeft];
}
@end

@interface ENRMListContainerView ()
#if !TARGET_OS_OSX
    <UITextViewDelegate, ENRMLinkContextMenuSource, UIContextMenuInteractionDelegate>
#endif
@property (nonatomic, copy) NSString *cachedMarkdown;
@property (nonatomic, copy) NSString *cachedPlainText;
@property (nonatomic, copy) NSString *cachedLinkedPlainText;
@end

@implementation ENRMListContainerView {
  ENRMListSegment *_listSegment;
  NSMutableArray<ENRMListItemView *> *_items;
}
- (instancetype)initWithConfig:(StyleConfig *)config
{
  if (self = [super initWithFrame:CGRectZero]) {
    self.config = config;
    _items = [NSMutableArray array];
    _allowFontScaling = YES;
    _lineBreakStrategy = NSLineBreakStrategyNone;
    _dynamicProps = [ENRMDynamicBlockProps new];
#if !TARGET_OS_OSX
    [self addInteraction:[[UIContextMenuInteraction alloc] initWithDelegate:self]];
#endif
  }
  return self;
}
- (BOOL)rootList
{
  return _listSegment.depth == 0;
}
- (BOOL)childrenInsideBlockquote
{
  return _listSegment.withinBlockquote;
}
- (NSArray<RCTUIView *> *)segmentViews
{
  return [_items copy];
}
#if !TARGET_OS_OSX
- (NSArray *)accessibilityElements
{
  return self.segmentViews;
}
#endif
- (void)setAccessibilityLabels:(ENRMAccessibilityLabels *)labels
{
  _accessibilityLabels = labels;
  NSMutableArray<RCTUIView *> *pending = [self.subviews mutableCopy];
  while (pending.count) {
    RCTUIView *view = pending.lastObject;
    [pending removeLastObject];
    if ([view conformsToProtocol:@protocol(ENRMNestedSegmentHost)])
      ((id<ENRMNestedSegmentHost>)view).accessibilityLabels = labels;
    else if ([view isKindOfClass:[EnrichedMarkdownInternalText class]])
      ((EnrichedMarkdownInternalText *)view).accessibilityLabels = labels;
    else if ([view isKindOfClass:[TableContainerView class]])
      ((TableContainerView *)view).accessibilityLabels = labels;
    else
      [pending addObjectsFromArray:view.subviews];
  }
}
- (void)applyListSegment:(ENRMListSegment *)segment
{
  _listSegment = segment;
  _writingDirectionMode = segment.writingDirectionMode;
  _resolvedLayoutDirection = segment.resolvedLayoutDirection;
  self.cachedMarkdown = markdownFromASTNode(segment.node);
  self.cachedPlainText = plainTextFromASTNode(segment.node);
  self.cachedLinkedPlainText = plainTextWithMarkdownLinksFromASTNode(segment.node);
  NSArray<ENRMListMarkerDescriptor *> *markers = ENRMListMarkers(segment, self.config);
  NSUInteger index = 0;
  for (MarkdownASTNode *node in segment.node.children) {
    if (node.type != MarkdownNodeTypeListItem)
      continue;
    ENRMListItemView *item;
    if (index < _items.count)
      item = _items[index];
    else {
      item = [[ENRMListItemView alloc] initWithFrame:CGRectZero];
      item.config = self.config;
      item.segmentViewRegistry = ENRMCreateNestedSegmentRegistry(self);
      item.markerDrawer = [[ListMarkerDrawer alloc] initWithConfig:self.config];
      item.taskTarget = [[ENRMListTaskTarget alloc] initWithFrame:CGRectZero];
      ENRMTapRecognizer *tap = [[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(taskTapped:)];
      [item.taskTarget addGestureRecognizer:tap];
      [item addSubview:item.taskTarget];
      [_items addObject:item];
      [self addSubview:item];
    }
    ENRMListMarkerDescriptor *marker = markers[index++];
    item.marker = marker;
    item.rightToLeft = ENRMListItemIsRTL(node, segment);
    item.contentInsets =
        item.rightToLeft ? UIEdgeInsetsMake(0, 0, 0, marker.indent) : UIEdgeInsetsMake(0, marker.indent, 0, 0);
    item.taskTarget.hidden = !marker.isTask;
    __weak ENRMListContainerView *weakSelf = self;
    NSString *text = plainTextFromASTNode(node);
    item.taskTarget.checked = marker.isChecked;
    item.taskTarget.canActivate = ^BOOL { return weakSelf.dynamicProps.enableTaskListItemToggle; };
    item.taskTarget.activate = ^{
      ENRMListContainerView *strongSelf = weakSelf;
      if (strongSelf.dynamicProps.enableTaskListItemToggle && strongSelf.onTaskListItemPress)
        strongSelf.onTaskListItemPress(marker.taskIndex, !marker.isChecked, text);
    };
#if !TARGET_OS_OSX
    item.taskTarget.isAccessibilityElement = marker.isTask;
    item.taskTarget.accessibilityLabel = text;

#endif
    [item applySegments:ENRMRenderListItemSegments(node, self.config, segment, marker, self.allowFontScaling,
                                                   self.lineBreakStrategy)
                  reset:NO];
  }
  while (_items.count > index) {
    [_items.lastObject removeFromSuperview];
    [_items removeLastObject];
  }
#if !TARGET_OS_OSX
  [self setNeedsLayout];
#else
  self.needsLayout = YES;
#endif
}
- (void)taskTapped:(ENRMTapRecognizer *)tap
{
  ENRMListTaskTarget *target = (ENRMListTaskTarget *)tap.view;
  if (target.activate)
    target.activate();
}
- (BOOL)isTaskTargetAtPoint:(CGPoint)point
{
  if (!self.dynamicProps.enableTaskListItemToggle)
    return NO;
  NSMutableArray<RCTUIView *> *pending = [self.subviews mutableCopy];
  while (pending.count) {
    RCTUIView *view = pending.lastObject;
    [pending removeLastObject];
    if (view.hidden)
      continue;
    if ([view isKindOfClass:[ENRMListTaskTarget class]] && CGRectContainsPoint(view.bounds, [view convertPoint:point
                                                                                                      fromView:self]))
      return YES;
    [pending addObjectsFromArray:view.subviews];
  }
  return NO;
}
- (void)configureNestedTextView:(EnrichedMarkdownInternalText *)view
{
  [view.textView addGestureRecognizer:[[ENRMTapRecognizer alloc] initWithTarget:self action:@selector(textTapped:)]];
#if !TARGET_OS_OSX
  view.textView.delegate = self;
#endif
}
- (void)textTapped:(ENRMTapRecognizer *)tap
{
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)tap.view;
  BOOL hadSelection = textView.selectedRange.length > 0;
  __weak ENRMListContainerView *weakSelf = self;
  if (ENRMHandleTapOnTextView(textView, tap, ^(NSString *url) {
        if (weakSelf.onLinkPress)
          weakSelf.onLinkPress(url);
      }))
    return;
  NSDictionary *image = imageAtTapLocation(textView, tap);
  if (image && self.onImagePress) {
    self.onImagePress(image[@"url"], image[@"altText"]);
    return;
  }
  if (!hadSelection && self.onTextPress) {
    NSUInteger index = textPressIndexAtTapLocation(textView, tap);
    if (index != NSNotFound)
      self.onTextPress(index, ENRMGetAttributedText(textView).string);
  }
}
- (void)setOuterDirection:(NSWritingDirection)outerDirection
{
  _outerDirection = outerDirection;
  _listSegment.outerDirection = outerDirection;
  for (ENRMContainerNodeView *item in self.segmentViews) {
    for (RCTUIView *view in item.segmentViews) {
      if ([view isKindOfClass:[ENRMBlockquoteContainerView class]])
        ((ENRMBlockquoteContainerView *)view).outerDirection = outerDirection;
      else if ([view isKindOfClass:[ENRMListContainerView class]])
        ((ENRMListContainerView *)view).outerDirection = outerDirection;
    }
  }
}
- (CGFloat)layoutItemsAtWidth:(CGFloat)width applyFrames:(BOOL)applyFrames
{
  CGFloat height = 0;
  for (NSUInteger i = 0; i < _items.count; i++) {
    if (i > 0 || _listSegment.depth > 0)
      height += self.config.listStyleItemSpacing;
    ENRMListItemView *item = _items[i];
    CGFloat itemHeight =
        [item computeContentHeightForWidth:MAX(1, width - item.contentInsets.left - item.contentInsets.right)];
    if (applyFrames)
      item.frame = CGRectMake(0, height, width, itemHeight);
    height += itemHeight;
  }
  return height;
}
- (CGFloat)measureHeight:(CGFloat)width
{
  return [self layoutItemsAtWidth:width applyFrames:NO];
}
#if !TARGET_OS_OSX
- (void)layoutSubviews
{
  [super layoutSubviews];
  [self layoutItemsAtWidth:self.bounds.size.width applyFrames:YES];
}
#else
- (void)layout
{
  [super layout];
  [self layoutItemsAtWidth:self.bounds.size.width applyFrames:YES];
}
#endif
+ (CGFloat)measureListSegment:(ENRMListSegment *)segment
                       config:(StyleConfig *)config
                        width:(CGFloat)width
             pointScaleFactor:(CGFloat)pointScaleFactor
             allowFontScaling:(BOOL)allowFontScaling
            lineBreakStrategy:(NSLineBreakStrategy)lineBreakStrategy
                   wrapCursor:(ENRMCodeBlockWrapCursor *)wrapCursor
                 slotMeasurer:(ENRMBlockSlotMeasurer *)slotMeasurer
                       origin:(CGPoint)origin
{
  NSArray<ENRMListMarkerDescriptor *> *markers = ENRMListMarkers(segment, config);
  CGFloat height = 0;
  NSUInteger index = 0;
  for (MarkdownASTNode *node in segment.node.children) {
    if (node.type != MarkdownNodeTypeListItem)
      continue;
    if (index > 0 || segment.depth > 0)
      height += config.listStyleItemSpacing;
    ENRMListMarkerDescriptor *marker = markers[index++];
    CGFloat inset = marker.indent;
    CGPoint bodyOrigin = CGPointMake(origin.x + (ENRMListItemIsRTL(node, segment) ? 0 : inset), origin.y + height);
    NSArray *body = ENRMRenderListItemSegments(node, config, segment, marker, allowFontScaling, lineBreakStrategy);
    height += ENRMMeasureSegmentsHeightViewFreeWithContext(
        body, config, MAX(1, width - inset), NO, pointScaleFactor, segment.writingDirectionMode,
        segment.resolvedLayoutDirection, segment.outerDirection, allowFontScaling, lineBreakStrategy, wrapCursor,
        slotMeasurer, bodyOrigin, segment.withinBlockquote);
  }
  return height;
}
- (void)copyMarkdownToPasteboard
{
  if (_cachedMarkdown.length > 0) {
    copyStringToPasteboard(_cachedMarkdown);
  }
}

- (void)copyPlainTextToPasteboard
{
  if (_cachedPlainText.length > 0) {
    NSMutableDictionary *items = [NSMutableDictionary dictionary];
    items[kUTIPlainText] = self.config.copyLinksAsMarkdown ? _cachedLinkedPlainText : _cachedPlainText;
    if (_cachedMarkdown.length > 0) {
      items[kUTIMarkdown] = _cachedMarkdown;
    }
    copyItemsToPasteboard(items);
  }
}

#if !TARGET_OS_OSX
- (UITextItemMenuConfiguration *)textView:(UITextView *)textView
             menuConfigurationForTextItem:(UITextItem *)textItem
                              defaultMenu:(UIMenu *)defaultMenu API_AVAILABLE(ios(17.0))
{
  return ENRMLinkMenuConfigurationForTextItem(textView, textItem, defaultMenu, self.dynamicProps.linkContextMenus,
                                              self.dynamicProps.enableLinkPreview, self.onLinkLongPress);
}

- (ENRMLinkContextMenus *)linkContextMenusForTextView:(UITextView *)textView
{
  return self.dynamicProps.linkContextMenus;
}

- (UIContextMenuConfiguration *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
                        configurationForMenuAtLocation:(CGPoint)location
{
  // Let the leaf interaction present a configured link menu, including nested tables.
  UIView *hit = [interaction.view hitTest:location withEvent:nil];
  while (hit && hit != interaction.view) {
    CGPoint point = [interaction.view convertPoint:location toView:hit];
    NSString *url = nil;
    if ([hit isKindOfClass:[UITextView class]])
      url = linkURLAtPoint((UITextView *)hit, point);
    else if ([hit isKindOfClass:[ENRMTableIOSGridView class]])
      url = [(ENRMTableIOSGridView *)hit linkAtPoint:point].url;
    if ([self.dynamicProps.linkContextMenus hasMenuForURL:url])
      return nil;
    hit = hit.superview;
  }
  if (!self.dynamicProps.enableBlockContextMenu) {
    return nil;
  }
  return [UIContextMenuConfiguration
      configurationWithIdentifier:nil
                  previewProvider:nil
                   actionProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
                     UIAction *copyPlainText =
                         [UIAction actionWithTitle:self.dynamicProps.menuCopyLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.on.doc"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyPlainTextToPasteboard]; }];

                     UIAction *copyMarkdown =
                         [UIAction actionWithTitle:self.dynamicProps.menuCopyAsMarkdownLabel
                                             image:[RCTUIImage systemImageNamed:@"doc.text"]
                                        identifier:nil
                                           handler:^(__kindof UIAction *action) { [self copyMarkdownToPasteboard]; }];

                     return [UIMenu menuWithTitle:@"" children:@[ copyPlainText, copyMarkdown ]];
                   }];
}
- (UITargetedPreview *)blockPreview
{
  if (self.window == nil)
    return nil;
  UIPreviewParameters *parameters = [[UIPreviewParameters alloc] init];
  parameters.backgroundColor = [UIColor systemBackgroundColor];
  for (UIView *view = self; view; view = view.superview) {
    UIColor *color = view.backgroundColor;
    if (color && CGColorGetAlpha(color.CGColor) > 0) {
      parameters.backgroundColor = color;
      break;
    }
  }
  return [[UITargetedPreview alloc] initWithView:self parameters:parameters];
}

- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
    previewForHighlightingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
  return [self blockPreview];
}

- (UITargetedPreview *)contextMenuInteraction:(UIContextMenuInteraction *)interaction
    previewForDismissingMenuWithConfiguration:(UIContextMenuConfiguration *)configuration
{
  return [self blockPreview];
}
#endif // !TARGET_OS_OSX
@end
