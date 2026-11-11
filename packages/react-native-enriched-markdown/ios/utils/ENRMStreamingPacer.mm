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

- (void)tick:(id)sender
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
#if TARGET_OS_OSX
  NSTimer *_link;
#else
  CADisplayLink *_link;
#endif
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

- (BOOL)updateMarkdown:(NSString *)markdown streaming:(BOOL)streaming smooth:(BOOL)smooth
{
  _markdown = [markdown copy];
  std::u16string text(markdown.length, u'\0');
  [markdown getCharacters:reinterpret_cast<unichar *>(text.data()) range:NSMakeRange(0, markdown.length)];
  CFTimeInterval now = CACurrentMediaTime();
  BOOL ends = _pacer.update(text, streaming, smooth, now);
  // What nothing holds back shows at once. New words wait for the next frame: revealing here as
  // well would render twice a frame.
  if (!_pacer.waiting(now)) {
    _shown = MIN(_pacer.revealed(now), _markdown.length);
  }
  [self runLinkWhileWaiting:now];
  return ends;
}

- (NSString *)markdownToRender
{
  return _shown >= _markdown.length ? _markdown : [_markdown substringToIndex:_shown];
}

- (void)reset
{
  [_link invalidate];
  _link = nil;
  _pacer = Markdown::StreamingPacer();
  _markdown = @"";
  _shown = 0;
}

// Runs the display link while words are waiting.
- (void)runLinkWhileWaiting:(CFTimeInterval)now
{
  if (_pacer.waiting(now)) {
    if (_link == nil) {
      ENRMPacerTicker *ticker = [[ENRMPacerTicker alloc] init];
      ticker.pacer = self;
      // Each reveal renders the text again: 30 a second keeps words flowing (they fade in at the
      // display's rate) without rendering more often than a stream's own updates would.
#if TARGET_OS_OSX
      // macOS has no CADisplayLink.
      _link = [NSTimer timerWithTimeInterval:1.0 / 30 target:ticker selector:@selector(tick:) userInfo:nil repeats:YES];
      [NSRunLoop.mainRunLoop addTimer:_link forMode:NSRunLoopCommonModes];
#else
      _link = [CADisplayLink displayLinkWithTarget:ticker selector:@selector(tick:)];
      _link.preferredFrameRateRange = CAFrameRateRangeMake(15, 30, 30);
      [_link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
#endif
    }
  } else {
    [_link invalidate];
    _link = nil;
  }
}

- (void)tick
{
  CFTimeInterval now = CACurrentMediaTime();
  NSUInteger shown = _shown;
  _shown = MIN(_pacer.revealed(now), _markdown.length);
  [self runLinkWhileWaiting:now];
  // The frame that ends the stream renders once, through done.
  if (_pacer.drained(now)) {
    _done();
  } else if (_shown != shown) {
    _reveal([self markdownToRender]);
  }
}

@end
