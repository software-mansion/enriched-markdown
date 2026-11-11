#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Paces a streaming view's markdown word by word with the core's StreamingPacer: the view renders
/// what has been revealed, and is handed more every frame while words are waiting, so its text,
/// layout and blocks grow word by word instead of in the bursts the markdown arrives in.
@interface ENRMStreamingPacer : NSObject

/// `reveal` gets the markdown to render once more of it is revealed; `done` runs once the stream
/// has ended and its last words have appeared. Both on the main queue.
- (instancetype)initWithReveal:(void (^)(NSString *markdown))reveal done:(void (^)(void))done;

/// Takes the view's markdown, its streaming prop and streamingConfig.smooth (the core's
/// StreamingPacer::update). Returns whether the stream ends now; otherwise, once it has ended,
/// `done` runs when its last words have appeared.
- (BOOL)updateMarkdown:(NSString *)markdown streaming:(BOOL)streaming smooth:(BOOL)smooth;
/// The part of `markdown` to render now.
@property (nonatomic, readonly) NSString *markdownToRender;
/// The whole markdown last given.
@property (nonatomic, readonly, copy) NSString *markdown;
/// Forgets everything and stops (a recycled view).
- (void)reset;

@end

NS_ASSUME_NONNULL_END
