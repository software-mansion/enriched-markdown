#import "../../ios/EnrichedMarkdown.h"
#import "../../ios/EnrichedMarkdownText.h"
#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#include <react/renderer/components/EnrichedMarkdownTextSpec/Props.h>

#include <functional>
#include <memory>
#include <string>

using facebook::react::EnrichedMarkdownProps;
using facebook::react::EnrichedMarkdownTextProps;

// What each view had rendered at each onStreamingEnd it emitted.
static NSMapTable<RCTViewComponentView *, NSMutableArray<NSString *> *> *ENRMStreamingEnds;
static NSMutableDictionary<NSString *, NSValue *> *ENRMOriginalEmitters;

static NSMutableArray<NSString *> *ENRMStreamingEndsOf(RCTViewComponentView *view)
{
  NSMutableArray<NSString *> *ends = [ENRMStreamingEnds objectForKey:view];
  if (!ends) {
    ends = [NSMutableArray array];
    [ENRMStreamingEnds setObject:ends forKey:view];
  }
  return ends;
}

// Counts emissions: emitStreamingEndIfPending emits iff the end is pending (no C++ dispatcher here).
static void ENRMRecordStreamingEnds(Class cls)
{
  SEL selector = NSSelectorFromString(@"emitStreamingEndIfPending");
  Method method = class_getInstanceMethod(cls, selector);
  Ivar pendingIvar = class_getInstanceVariable(cls, "_streamEndPending");
  Ivar renderedIvar = class_getInstanceVariable(cls, "_renderedMarkdown");
  NSCAssert(method && pendingIvar && renderedIvar, @"%@ no longer has the streaming end members", cls);
  const ptrdiff_t pendingOffset = ivar_getOffset(pendingIvar);
  IMP original = method_getImplementation(method);
  ENRMOriginalEmitters[NSStringFromClass(cls)] = [NSValue valueWithPointer:(const void *)original];
  method_setImplementation(method, imp_implementationWithBlock(^(RCTViewComponentView *view) {
                             const BOOL pending = *(BOOL *)((uint8_t *)(__bridge void *)view + pendingOffset);
                             ((void (*)(id, SEL))original)(view, selector);
                             if (pending) {
                               [ENRMStreamingEndsOf(view) addObject:[object_getIvar(view, renderedIvar) copy] ?: @""];
                             }
                           }));
}

static void ENRMRestoreStreamingEnds(Class cls)
{
  Method method = class_getInstanceMethod(cls, NSSelectorFromString(@"emitStreamingEndIfPending"));
  method_setImplementation(method, (IMP)[ENRMOriginalEmitters[NSStringFromClass(cls)] pointerValue]);
}

static BOOL ENRMSpinUntil(NSTimeInterval timeout, BOOL (^condition)(void))
{
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:timeout];
  while (!condition() && deadline.timeIntervalSinceNow > 0) {
    [NSRunLoop.currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
  }
  return condition();
}

static void ENRMSpin(NSTimeInterval duration)
{
  ENRMSpinUntil(duration, ^{ return NO; });
}

// A view driven the way Fabric mounts it: props, then finalizeUpdates.
@interface ENRMStreamingEndHost : NSObject
@property (nonatomic, readonly) RCTViewComponentView *view;
@property (nonatomic, readonly) NSArray<NSString *> *ends;
+ (NSArray<ENRMStreamingEndHost *> *)allViews;
- (void)setMarkdown:(NSString *)markdown streaming:(BOOL)streaming;
- (void)setMarkdown:(NSString *)markdown streaming:(BOOL)streaming smooth:(BOOL)smooth;
- (BOOL)hasRendered:(NSString *)markdown;
- (void)recycle;
@end

@interface ENRMStreamingEndHost ()
- (instancetype)initWithView:(RCTViewComponentView *)view
                       apply:(std::function<void(const std::string &, bool, bool)>)apply;
@end

template <typename ViewProps> static ENRMStreamingEndHost *ENRMMakeStreamingEndHost(RCTViewComponentView *view)
{
  auto props = std::make_shared<std::shared_ptr<const ViewProps>>(std::make_shared<const ViewProps>());
  return [[ENRMStreamingEndHost alloc]
      initWithView:view
             apply:[view, props](const std::string &markdown, bool streaming, bool smooth) {
               auto next = std::make_shared<ViewProps>(**props);
               next->markdown = markdown;
               next->streaming = streaming;
               next->streamingConfig.smooth = smooth;
               std::shared_ptr<const ViewProps> applied = next;
               [view updateProps:applied oldProps:*props];
               [view finalizeUpdates:RNComponentViewUpdateMaskProps];
               *props = applied;
             }];
}

@implementation ENRMStreamingEndHost {
  std::function<void(const std::string &, bool, bool)> _apply;
}

- (instancetype)initWithView:(RCTViewComponentView *)view
                       apply:(std::function<void(const std::string &, bool, bool)>)apply
{
  if (self = [super init]) {
    _view = view;
    _apply = std::move(apply);
  }
  return self;
}

+ (NSArray<ENRMStreamingEndHost *> *)allViews
{
  const CGRect frame = CGRectMake(0, 0, 320, 480);
  return @[
    ENRMMakeStreamingEndHost<EnrichedMarkdownProps>([[EnrichedMarkdown alloc] initWithFrame:frame]),
    ENRMMakeStreamingEndHost<EnrichedMarkdownTextProps>([[EnrichedMarkdownText alloc] initWithFrame:frame]),
  ];
}

- (void)setMarkdown:(NSString *)markdown streaming:(BOOL)streaming
{
  [self setMarkdown:markdown streaming:streaming smooth:NO];
}

- (void)setMarkdown:(NSString *)markdown streaming:(BOOL)streaming smooth:(BOOL)smooth
{
  _apply(std::string(markdown.UTF8String), streaming, smooth);
}

- (NSArray<NSString *> *)ends
{
  return [ENRMStreamingEnds objectForKey:_view] ?: @[];
}

- (BOOL)hasRendered:(NSString *)markdown
{
  return [(id)_view hasRenderedMarkdown:markdown];
}

- (void)recycle
{
  [_view prepareForRecycle];
}

- (NSString *)description
{
  return NSStringFromClass(_view.class);
}

@end

static NSString *const kStreamStart = @"Streaming **markdown**";
static NSString *const kStreamEnd = @"Streaming **markdown** has ended.\n\nWith a second paragraph.";

@interface ENRMStreamingEndTests : XCTestCase
@end

@implementation ENRMStreamingEndTests

+ (void)setUp
{
  [super setUp];
  ENRMStreamingEnds = [NSMapTable weakToStrongObjectsMapTable];
  ENRMOriginalEmitters = [NSMutableDictionary dictionary];
  ENRMRecordStreamingEnds(EnrichedMarkdown.class);
  ENRMRecordStreamingEnds(EnrichedMarkdownText.class);
}

+ (void)tearDown
{
  ENRMRestoreStreamingEnds(EnrichedMarkdown.class);
  ENRMRestoreStreamingEnds(EnrichedMarkdownText.class);
  [super tearDown];
}

- (void)testEndsOnceAfterTheFinalRenderApplies
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:YES];
    XCTAssertEqual(host.ends.count, 0u, @"%@", host);

    [host setMarkdown:kStreamEnd streaming:NO];
    XCTAssertFalse([host hasRendered:kStreamEnd], @"%@: the final render is still in flight", host);
    XCTAssertEqual(host.ends.count, 0u, @"%@ ended before the final render applied", host);

    XCTAssertTrue(ENRMSpinUntil(5, ^{ return host.ends.count > 0; }), @"%@ never ended", host);
    XCTAssertEqualObjects(host.ends.firstObject, kStreamEnd, @"%@ ended before showing the whole text", host);
    ENRMSpin(0.3);
    XCTAssertEqual(host.ends.count, 1u, @"%@", host);
  }
}

- (void)testEndsWhenThereIsNothingToRender
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:@"" streaming:YES];
    [host setMarkdown:@"" streaming:NO];
    ENRMSpinUntil(1, ^{ return host.ends.count > 0; });
    XCTAssertEqual(host.ends.count, 1u, @"%@", host);
  }
}

- (void)testSmoothPacingEndsAfterTheRevealDrains
{
  NSMutableString *words = [NSMutableString stringWithString:kStreamStart];
  for (int i = 0; i < 60; i++) {
    [words appendFormat:@" word%d", i];
  }
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:YES smooth:YES];
    ENRMSpinUntil(2, ^{ return [host hasRendered:kStreamStart]; });
    [host setMarkdown:words streaming:YES smooth:YES];
    [host setMarkdown:words streaming:NO smooth:YES];
    XCTAssertFalse([host hasRendered:words], @"%@: the words should still be waiting", host);
    XCTAssertEqual(host.ends.count, 0u, @"%@ ended before the reveal drained", host);

    XCTAssertTrue(ENRMSpinUntil(5, ^{ return host.ends.count > 0; }), @"%@ never ended", host);
    XCTAssertEqualObjects(host.ends.firstObject, words, @"%@ ended before the last words appeared", host);
    ENRMSpin(0.3);
    XCTAssertEqual(host.ends.count, 1u, @"%@", host);
  }
}

- (void)testARestartedStreamEndsAgain
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:YES];
    [host setMarkdown:kStreamEnd streaming:NO];
    XCTAssertTrue(ENRMSpinUntil(5, ^{ return host.ends.count == 1; }), @"%@", host);

    [host setMarkdown:@"A new" streaming:YES];
    ENRMSpin(0.1);
    XCTAssertEqual(host.ends.count, 1u, @"%@ ended again when the stream restarted", host);
    [host setMarkdown:@"A new answer." streaming:NO];
    XCTAssertTrue(ENRMSpinUntil(5, ^{ return host.ends.count == 2; }), @"%@ did not end the second stream", host);
    XCTAssertEqualObjects(host.ends.lastObject, @"A new answer.", @"%@", host);
    ENRMSpin(0.3);
    XCTAssertEqual(host.ends.count, 2u, @"%@", host);
  }
}

- (void)testAStreamRestartedBeforeItsFinalRenderEndsOnce
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:YES];
    [host setMarkdown:kStreamEnd streaming:NO];
    [host setMarkdown:@"A new" streaming:YES];
    XCTAssertEqual(host.ends.count, 1u, @"%@: the restart ends the stream before it", host);

    [host setMarkdown:@"A new answer." streaming:NO];
    XCTAssertTrue(ENRMSpinUntil(5, ^{ return host.ends.count == 2; }), @"%@ did not end the second stream", host);
    ENRMSpin(0.3);
    XCTAssertEqual(host.ends.count, 2u, @"%@", host);
  }
}

- (void)testAViewThatNeverStreamedDoesNotEnd
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:NO];
    [host setMarkdown:kStreamEnd streaming:NO];
    XCTAssertTrue(ENRMSpinUntil(5, ^{ return [host hasRendered:kStreamEnd]; }), @"%@", host);
    ENRMSpin(0.2);
    XCTAssertEqual(host.ends.count, 0u, @"%@", host);
  }
}

- (void)testRecyclingMidStreamDoesNotEnd
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:YES];
    [host recycle];
    [host setMarkdown:kStreamEnd streaming:NO];
    ENRMSpin(0.3);
    XCTAssertEqual(host.ends.count, 0u, @"%@", host);
  }
}

- (void)testRecyclingBeforeTheFinalRenderAppliesDoesNotEnd
{
  for (ENRMStreamingEndHost *host in [ENRMStreamingEndHost allViews]) {
    [host setMarkdown:kStreamStart streaming:YES];
    [host setMarkdown:kStreamEnd streaming:NO];
    [host recycle];
    ENRMSpin(0.3);
    XCTAssertEqual(host.ends.count, 0u, @"%@", host);
  }
}

@end
