#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Paces a streaming view's markdown word by word with the core's StreamingPacer: the view renders
/// what has been revealed, and is handed more every frame while words are waiting, so its text,
/// layout and blocks grow word by word instead of in the bursts the markdown arrives in.
@interface ENRMStreamingPacer : NSObject

/// `reveal` gets the markdown to render once more of it is revealed; `done` runs once nothing is
/// waiting after `finish`. Both on the main queue.
- (instancetype)initWithReveal:(void (^)(NSString *markdown))reveal done:(void (^)(void))done;

/// The part of `markdown` to render now. Paced while `pacing` and `markdown` continues the last
/// one; otherwise all of it.
- (NSString *)markdownToRender:(NSString *)markdown pacing:(BOOL)pacing;
/// The stream ended: what is waiting appears within 200 ms, then `done` runs; nothing runs when
/// nothing was waiting.
- (void)finish;
/// Streaming started again: `done` no longer runs for the last `finish`.
- (void)resume;
/// Whether more is still to be revealed.
@property (nonatomic, readonly) BOOL waiting;
/// The whole markdown last given.
@property (nonatomic, readonly, copy) NSString *markdown;
/// Forgets everything and stops (a recycled view).
- (void)reset;

@end

NS_ASSUME_NONNULL_END
