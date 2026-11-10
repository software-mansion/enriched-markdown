#import "ENRMStreamingPacer.h"
#include "StreamingPacer.hpp"
#import <QuartzCore/QuartzCore.h>
#include <string>

@class ENRMStreamingPacer;

// The display link's target: it would retain the pacer.
@interface ENRMPacerTicker : NSObject
@property (nonatomic, weak) ENRMStreamingPacer *pacer;
@end

@interface ENRMStreamingPacer ()
- (void)tick;
@end

@implementation ENRMPacerTicker

- (void)tick:(CADisplayLink *)link
{
  [self.pacer tick];
}

@end

@implementation ENRMStreamingPacer {
  Markdown::StreamingPacer _pacer;
  void (^_reveal)(NSString *);
  void (^_done)(void);
  NSString *_markdown;
  NSUInteger _shown;
  BOOL _finishing;
  CADisplayLink *_link;
}

- (instancetype)initWithReveal:(void (^)(NSString *))reveal done:(void (^)(void))done
{
  if (self = [super init]) {
    _reveal = [reveal copy];
    _done = [done copy];
    _markdown = @"";
  }
  return self;
}

- (void)dealloc
{
  [_link invalidate];
}

- (NSString *)markdown
{
  return _markdown;
}

- (NSString *)markdownToRender:(NSString *)markdown pacing:(BOOL)pacing
{
  NSUInteger previous = _markdown.length;
  BOOL continues = previous > 0 && markdown.length >= previous && [markdown hasPrefix:_markdown];
  _markdown = [markdown copy];
  if (!pacing || !continues) {
    _pacer.reset(markdown.length);
    _finishing = NO;
    [self update];
    return [self shownMarkdown];
  }
  if (markdown.length > previous) {
    std::u16string added(markdown.length - previous, u'\0');
    [markdown getCharacters:reinterpret_cast<unichar *>(added.data())
                      range:NSMakeRange(previous, markdown.length - previous)];
    CFTimeInterval now = CACurrentMediaTime();
    _pacer.append(previous, added, now);
    // Text arriving after the end of the stream drains with the rest.
    if (_finishing) {
      _pacer.finish(now);
    }
  }
  // The next frame reveals the new words: revealing here as well would render twice a frame.
  [self runLinkWhileWaiting];
  return [self shownMarkdown];
}

- (void)finish
{
  _pacer.finish(CACurrentMediaTime());
  [self update];
  _finishing = _link != nil;
}

- (void)resume
{
  _finishing = NO;
}

- (BOOL)waiting
{
  return _finishing || _pacer.waiting(CACurrentMediaTime());
}

- (void)reset
{
  [_link invalidate];
  _link = nil;
  _pacer.reset(0);
  _markdown = @"";
  _shown = 0;
  _finishing = NO;
}

- (NSString *)shownMarkdown
{
  return _shown >= _markdown.length ? _markdown : [_markdown substringToIndex:_shown];
}

// Takes what is revealed now and keeps the display link running only while words are waiting.
- (void)update
{
  _shown = MIN(_pacer.revealed(CACurrentMediaTime()), _markdown.length);
  [self runLinkWhileWaiting];
}

// Runs the display link while words are waiting or revealed ones are still to be shown.
- (void)runLinkWhileWaiting
{
  CFTimeInterval now = CACurrentMediaTime();
  if (_pacer.waiting(now) || MIN(_pacer.revealed(now), _markdown.length) != _shown) {
    if (_link == nil) {
      ENRMPacerTicker *ticker = [[ENRMPacerTicker alloc] init];
      ticker.pacer = self;
      _link = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
      // Each reveal renders the text again: 30 a second keeps words flowing (they fade in at the
      // display's rate) without rendering more often than a stream's own updates would.
      _link.preferredFrameRateRange = CAFrameRateRangeMake(15, 30, 30);
      [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    }
  } else {
    [_link invalidate];
    _link = nil;
  }
}

- (void)tick
{
  NSUInteger shown = _shown;
  [self update];
  if (_shown != shown) {
    _reveal([self shownMarkdown]);
  }
  if (_link == nil && _finishing) {
    _finishing = NO;
    _done();
  }
}

@end
