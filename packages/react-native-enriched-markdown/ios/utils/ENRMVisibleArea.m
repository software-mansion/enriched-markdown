#import "ENRMVisibleArea.h"

const CGFloat ENRMVisibleAreaMargin = 600;

#if !TARGET_OS_OSX
static void *kENRMVisibleAreaContext = &kENRMVisibleAreaContext;
#endif

@implementation ENRMVisibleArea {
  __weak RCTUIView *_view;
  void (^_onChange)(void);
#if !TARGET_OS_OSX
  __weak UIWindow *_observedWindow;
  NSArray<UIScrollView *> *_scrollViews;
  // The views from this one up to the outermost scroll view: an animated transform moves it in them.
  NSArray<CALayer *> *_movingLayers;
#endif
}

- (instancetype)initWithView:(RCTUIView *)view onChange:(void (^)(void))onChange
{
  if (self = [super init]) {
    _view = view;
    _onChange = [onChange copy];
  }
  return self;
}

#if !TARGET_OS_OSX
- (void)dealloc
{
  [self observeAncestorsOfView:nil];
}

- (CGRect)visibleRect
{
  UIView *view = _view;
  UIWindow *window = view.window;
  if (window != _observedWindow) {
    _observedWindow = window;
    [self observeAncestorsOfView:window != nil ? view : nil];
  }
  if (window == nil) {
    return CGRectNull;
  }
  // Only the scroll views decide, and only vertically: a navigation transition or a sheet sliding in
  // moves the scroll views with the view, with nothing to say when it came into view.
  if (_scrollViews.count == 0) {
    return CGRectInfinite;
  }
  CGFloat top = -CGFLOAT_MAX;
  CGFloat bottom = CGFLOAT_MAX;
  for (UIScrollView *scrollView in _scrollViews) {
    CGRect shown = [scrollView convertRect:scrollView.bounds toView:view];
    top = MAX(top, CGRectGetMinY(shown));
    bottom = MIN(bottom, CGRectGetMaxY(shown));
  }
  if (bottom <= top) {
    return CGRectZero;
  }
  return CGRectMake(-CGFLOAT_MAX / 4, top, CGFLOAT_MAX / 2, bottom - top);
}

- (CGRect)visibleRectInView:(RCTUIView *)view
{
  CGRect visible = [self visibleRect];
  UIView *areaView = _view;
  if (CGRectIsNull(visible) || ![view isDescendantOfView:areaView]) {
    return CGRectNull;
  }
  if (view == areaView || CGRectIsInfinite(visible) || CGRectIsEmpty(visible)) {
    return visible;
  }
  // Vertically only, as visibleRect: the rect is too wide to convert.
  CGFloat top = [areaView convertPoint:CGPointMake(0, CGRectGetMinY(visible)) toView:view].y;
  CGFloat bottom = [areaView convertPoint:CGPointMake(0, CGRectGetMaxY(visible)) toView:view].y;
  return CGRectMake(-CGFLOAT_MAX / 4, top, CGFLOAT_MAX / 2, bottom - top);
}

// Scrolls and resizes of the scroll views (their layers' bounds), and transforms below the outermost
// one (Animated's native driver sets them with no layout): a transform above it moves the scroll
// views along.
- (void)observeAncestorsOfView:(nullable UIView *)view
{
  for (UIScrollView *scrollView in _scrollViews) {
    [scrollView.layer removeObserver:self forKeyPath:@"bounds" context:kENRMVisibleAreaContext];
  }
  for (CALayer *layer in _movingLayers) {
    [layer removeObserver:self forKeyPath:@"transform" context:kENRMVisibleAreaContext];
  }
  NSMutableArray<UIScrollView *> *scrollViews = [NSMutableArray array];
  NSMutableArray<CALayer *> *movingLayers = [NSMutableArray array];
  NSMutableArray<CALayer *> *belowScrollView = [NSMutableArray array];
  for (UIView *ancestor = view; ancestor != nil; ancestor = ancestor.superview) {
    if (ancestor != view && [ancestor isKindOfClass:[UIScrollView class]]) {
      [scrollViews addObject:(UIScrollView *)ancestor];
      [movingLayers addObjectsFromArray:belowScrollView];
      [belowScrollView removeAllObjects];
    }
    [belowScrollView addObject:ancestor.layer];
  }
  _scrollViews = scrollViews;
  _movingLayers = movingLayers;
  for (UIScrollView *scrollView in _scrollViews) {
    [scrollView.layer addObserver:self forKeyPath:@"bounds" options:0 context:kENRMVisibleAreaContext];
  }
  for (CALayer *layer in _movingLayers) {
    [layer addObserver:self forKeyPath:@"transform" options:0 context:kENRMVisibleAreaContext];
  }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey, id> *)change
                       context:(void *)context
{
  if (context != kENRMVisibleAreaContext) {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    return;
  }
  _onChange();
}
#else
- (CGRect)visibleRect
{
  return CGRectNull;
}

- (CGRect)visibleRectInView:(RCTUIView *)view
{
  return CGRectNull;
}
#endif

@end
