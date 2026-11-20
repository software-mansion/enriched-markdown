#import "ENRMHighlightCoordinator.h"
#import "TextViewLayoutManager.h"
#include <vector>

static NSString *const ENRMBlockSeparator = @"\n";

@implementation ENRMRenderedTextBlock

- (instancetype)initWithStart:(NSInteger)start end:(NSInteger)end kind:(NSString *)kind
{
  self = [super init];
  if (self) {
    _start = start;
    _end = end;
    _kind = [kind copy];
  }
  return self;
}

- (BOOL)isEqual:(id)object
{
  if (![object isKindOfClass:[ENRMRenderedTextBlock class]]) {
    return NO;
  }
  ENRMRenderedTextBlock *other = object;
  return _start == other.start && _end == other.end && [_kind isEqualToString:other.kind];
}

- (NSUInteger)hash
{
  return (NSUInteger)_start ^ ((NSUInteger)_end << 20) ^ _kind.hash;
}

@end

@implementation ENRMHighlightRect

- (instancetype)initWithIndex:(NSInteger)index rect:(CGRect)rect
{
  self = [super init];
  if (self) {
    _index = index;
    _rect = rect;
  }
  return self;
}

- (BOOL)isCloseTo:(ENRMHighlightRect *)other
{
  CGRect a = _rect;
  CGRect b = other.rect;
  return _index == other.index && fabs(a.origin.x - b.origin.x) < 0.5 && fabs(a.origin.y - b.origin.y) < 0.5 &&
         fabs(a.size.width - b.size.width) < 0.5 && fabs(a.size.height - b.size.height) < 0.5;
}

@end

static BOOL ENRMIsTextBlock(RCTUIView *view)
{
  return [view isKindOfClass:[ENRMPlatformTextView class]];
}

/// The part of `highlight` inside `block`, in the block's own offsets, or nil.
static ENRMTextHighlight *_Nullable ENRMHighlightInBlock(ENRMTextHighlight *highlight, NSRange block)
{
  NSRange part = NSIntersectionRange(highlight.range, block);
  if (part.length == 0) {
    return nil;
  }
  return [highlight highlightWithRange:NSMakeRange(part.location - block.location, part.length)];
}

@implementation ENRMHighlightCoordinator {
  __weak RCTUIView *_host;
  NSArray<RCTUIView *> *_blockViews;
  std::vector<NSRange> _blockRanges;
  // Tints over blocks that draw their own text, and the highlights they show.
  NSMapTable<RCTUIView *, NSArray<RCTUIView *> *> *_overlays;
  NSMapTable<RCTUIView *, NSArray<ENRMTextHighlight *> *> *_overlayHighlights;
  NSArray<ENRMHighlightRect *> *_reportedRects;
}

- (instancetype)initWithHost:(RCTUIView *)host
{
  self = [super init];
  if (self) {
    _host = host;
    _highlights = @[];
    _blockViews = @[];
    _renderedText = @"";
    _renderedBlocks = @[];
    _overlays = [NSMapTable weakToStrongObjectsMapTable];
    _overlayHighlights = [NSMapTable weakToStrongObjectsMapTable];
    _reportedRects = @[];
  }
  return self;
}

- (BOOL)setBlockViews:(NSArray<RCTUIView *> *)blockViews
{
  NSMutableArray<RCTUIView *> *views = [NSMutableArray arrayWithCapacity:blockViews.count];
  NSMutableArray<ENRMRenderedTextBlock *> *blocks = [NSMutableArray arrayWithCapacity:blockViews.count];
  std::vector<NSRange> ranges;
  ranges.reserve(blockViews.count);
  NSMutableString *text = [NSMutableString string];
  for (RCTUIView *view in blockViews) {
    NSString *blockText;
    NSString *kind;
    if (ENRMIsTextBlock(view)) {
      blockText = ENRMGetAttributedText((ENRMPlatformTextView *)view).string;
      kind = @"text";
    } else if ([view conformsToProtocol:@protocol(ENRMRenderedTextProviding)]) {
      id<ENRMRenderedTextProviding> provider = (id<ENRMRenderedTextProviding>)view;
      blockText = provider.renderedText;
      kind = provider.renderedTextKind;
    } else {
      continue;
    }
    if (views.count > 0) {
      [text appendString:ENRMBlockSeparator];
    }
    NSUInteger start = text.length;
    [text appendString:blockText ?: @""];
    NSRange range = NSMakeRange(start, text.length - start);
    [views addObject:view];
    ranges.push_back(range);
    [blocks addObject:[[ENRMRenderedTextBlock alloc] initWithStart:(NSInteger)range.location
                                                               end:(NSInteger)NSMaxRange(range)
                                                              kind:kind]];
  }

  // Views that left the document drop what they drew.
  for (RCTUIView *view in _blockViews) {
    if ([views indexOfObjectIdenticalTo:view] == NSNotFound) {
      [self applyHighlights:@[] toBlock:view];
    }
  }
  BOOL changed = ![_renderedText isEqualToString:text] || ![_renderedBlocks isEqualToArray:blocks];
  _blockViews = [views copy];
  _blockRanges = std::move(ranges);
  _renderedText = [text copy];
  _renderedBlocks = [blocks copy];
  [self applyHighlights];
  return changed;
}

- (void)setHighlights:(NSArray<ENRMTextHighlight *> *)highlights
{
  if ([_highlights isEqualToArray:highlights]) {
    return;
  }
  _highlights = [highlights copy];
  [self applyHighlights];
  [self reportLayout];
}

- (void)applyHighlights
{
  [_blockViews enumerateObjectsUsingBlock:^(RCTUIView *view, NSUInteger index, BOOL *stop) {
    NSMutableArray<ENRMTextHighlight *> *local = [NSMutableArray array];
    for (ENRMTextHighlight *highlight in self->_highlights) {
      ENRMTextHighlight *part = ENRMHighlightInBlock(highlight, self->_blockRanges[index]);
      if (part != nil) {
        [local addObject:part];
      }
    }
    [self applyHighlights:local toBlock:view];
  }];
}

- (void)applyHighlights:(NSArray<ENRMTextHighlight *> *)highlights toBlock:(RCTUIView *)view
{
  if (ENRMIsTextBlock(view)) {
    NSLayoutManager *layoutManager = ((ENRMPlatformTextView *)view).layoutManager;
    if ([layoutManager isKindOfClass:[TextViewLayoutManager class]]) {
      ((TextViewLayoutManager *)layoutManager).textHighlights = highlights;
    }
    return;
  }
  NSArray<ENRMTextHighlight *> *shown = [_overlayHighlights objectForKey:view] ?: @[];
  if ([shown isEqualToArray:highlights]) {
    return;
  }
  for (RCTUIView *overlay in [_overlays objectForKey:view]) {
    [overlay removeFromSuperview];
  }
  NSMutableArray<RCTUIView *> *overlays = [NSMutableArray arrayWithCapacity:highlights.count];
  for (ENRMTextHighlight *highlight in highlights) {
    RCTUIView *overlay = [[RCTUIView alloc] initWithFrame:view.bounds];
#if !TARGET_OS_OSX
    overlay.userInteractionEnabled = NO;
    overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    overlay.backgroundColor = highlight.color;
#else
    overlay.wantsLayer = YES;
    overlay.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    overlay.layer.backgroundColor = highlight.color.CGColor;
#endif
    overlay.layer.cornerRadius = view.layer.cornerRadius;
    [view addSubview:overlay];
    [overlays addObject:overlay];
  }
  [_overlays setObject:overlays forKey:view];
  [_overlayHighlights setObject:[highlights copy] forKey:view];
}

#pragma mark - Layout

- (CGRect)hostRectOfHighlight:(ENRMTextHighlight *)highlight inBlock:(RCTUIView *)view host:(RCTUIView *)host
{
  if (!ENRMIsTextBlock(view)) {
    return [view convertRect:view.bounds toView:host];
  }
  ENRMPlatformTextView *textView = (ENRMPlatformTextView *)view;
  CGRect bounds = ENRMTextHighlightBounds(highlight, textView.layoutManager);
  if (CGRectIsNull(bounds)) {
    return CGRectNull;
  }
#if !TARGET_OS_OSX
  UIEdgeInsets inset = textView.textContainerInset;
  CGPoint origin = CGPointMake(inset.left, inset.top);
#else
  CGPoint origin = textView.textContainerOrigin;
#endif
  return [textView convertRect:CGRectOffset(bounds, origin.x, origin.y) toView:host];
}

- (void)reportLayout
{
  RCTUIView *host = _host;
  if (host == nil) {
    return;
  }
  std::vector<CGRect> unions(_highlights.count, CGRectNull);
  for (NSUInteger blockIndex = 0; blockIndex < _blockViews.count; blockIndex++) {
    RCTUIView *view = _blockViews[blockIndex];
    for (NSUInteger index = 0; index < _highlights.count; index++) {
      ENRMTextHighlight *part = ENRMHighlightInBlock(_highlights[index], _blockRanges[blockIndex]);
      if (part == nil) {
        continue;
      }
      CGRect rect = [self hostRectOfHighlight:part inBlock:view host:host];
      if (!CGRectIsNull(rect)) {
        unions[index] = CGRectUnion(unions[index], rect);
      }
    }
  }
  NSMutableArray<ENRMHighlightRect *> *rects = [NSMutableArray array];
  for (NSUInteger index = 0; index < unions.size(); index++) {
    if (!CGRectIsNull(unions[index])) {
      [rects addObject:[[ENRMHighlightRect alloc] initWithIndex:(NSInteger)index rect:unions[index]]];
    }
  }

  if (rects.count == _reportedRects.count) {
    BOOL same = YES;
    for (NSUInteger i = 0; i < rects.count && same; i++) {
      same = [rects[i] isCloseTo:_reportedRects[i]];
    }
    if (same) {
      return;
    }
  }
  _reportedRects = [rects copy];
  if (self.onLayout) {
    self.onLayout(_reportedRects);
  }
}

- (void)reset
{
  _highlights = @[];
  [self setBlockViews:@[]];
  _reportedRects = @[];
}

@end
