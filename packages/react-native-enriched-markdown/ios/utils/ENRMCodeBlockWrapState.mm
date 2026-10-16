#import "ENRMCodeBlockWrapState.h"
#import "ENRMContainerNodeView.h"

void ENRMCollectCodeBlockViews(NSArray<RCTUIView *> *segmentViews,
                               NSMutableArray<ENRMCodeBlockContainerView *> *codeBlockViews)
{
  for (RCTUIView *view in segmentViews) {
    if ([view isKindOfClass:[ENRMCodeBlockContainerView class]]) {
      [codeBlockViews addObject:(ENRMCodeBlockContainerView *)view];
    } else if ([view isKindOfClass:[ENRMContainerNodeView class]]) {
      ENRMCollectCodeBlockViews(((ENRMContainerNodeView *)view).segmentViews, codeBlockViews);
    }
  }
}

@implementation ENRMCodeBlockWrapCursor {
  NSSet<NSNumber *> *_wrapped;
  NSUInteger _nextIndex;
}

- (instancetype)initWithWrapped:(NSSet<NSNumber *> *)wrapped
{
  if (self = [super init]) {
    _wrapped = wrapped;
  }
  return self;
}

- (BOOL)nextIsWrapped
{
  return [_wrapped containsObject:@(_nextIndex++)];
}

@end

@interface ENRMCodeBlockWrapState ()
@property (atomic, copy, readwrite) NSSet<NSNumber *> *indices;
@end

@implementation ENRMCodeBlockWrapState {
  NSArray<ENRMCodeBlockContainerView *> * (^_codeBlockViews)(void);
  void (^_onHeightChanged)(void);
}

- (instancetype)initWithCodeBlockViews:(NSArray<ENRMCodeBlockContainerView *> * (^)(void))codeBlockViews
                       onHeightChanged:(void (^)(void))onHeightChanged
{
  if (self = [super init]) {
    _codeBlockViews = [codeBlockViews copy];
    _onHeightChanged = [onHeightChanged copy];
    self.indices = [NSSet set];
  }
  return self;
}

- (BOOL)updateEnabled:(BOOL)enabled
{
  if (_enabled == enabled) {
    return NO;
  }
  _enabled = enabled;
  BOOL cleared = !enabled && self.indices.count > 0;
  if (cleared) {
    self.indices = [NSSet set];
  }
  [self sync];
  return cleared;
}

- (BOOL)markdownPropDidChangeFrom:(const std::string &)previous
                               to:(const std::string &)next
                         rendered:(NSString *)rendered
{
  if (self.indices.count == 0) {
    return NO;
  }
  const bool echoesRendered = rendered != nil && next.compare(rendered.UTF8String) == 0;
  if (echoesRendered || ENRMKeepsCodeBlockWrapState(previous, next)) {
    return NO;
  }
  self.indices = [NSSet set];
  return YES;
}

- (void)sync
{
  NSSet<NSNumber *> *wrapped = self.indices;
  __weak ENRMCodeBlockWrapState *weakSelf = self;
  [_codeBlockViews() enumerateObjectsUsingBlock:^(ENRMCodeBlockContainerView *view, NSUInteger index, BOOL *stop) {
    view.onWrapToggle = ^(ENRMCodeBlockContainerView *toggled) { [weakSelf toggle:toggled]; };
    view.showsWrapButton = self->_enabled;
    view.wrapped = self->_enabled && [wrapped containsObject:@(index)];
  }];
}

- (void)toggle:(ENRMCodeBlockContainerView *)view
{
  if (!_enabled) {
    return;
  }
  NSUInteger index = [_codeBlockViews() indexOfObjectIdenticalTo:view];
  if (index == NSNotFound) {
    return;
  }
  NSMutableSet<NSNumber *> *wrapped = [self.indices mutableCopy];
  if ([wrapped containsObject:@(index)]) {
    [wrapped removeObject:@(index)];
  } else {
    [wrapped addObject:@(index)];
  }
  self.indices = wrapped;
  [self sync];
  _onHeightChanged();
}

- (void)reset
{
  _enabled = NO;
  self.indices = [NSSet set];
}

@end
