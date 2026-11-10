#pragma once
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ENRMStreamingEffectType) {
  ENRMStreamingEffectNone,
  ENRMStreamingEffectFade,
  ENRMStreamingEffectGradient,
};

/// How the newest characters of a streaming text look: from their age (fade) or their distance from
/// the end of the text (gradient), computed by the core's StreamingEffects. The text never changes;
/// the tiles draw the characters with these looks.
@interface ENRMStreamingEffects : NSObject

/// The effect and its options (`duration` in seconds; `length` in characters; nil colors keep each
/// character's own). Starts over.
- (void)configureType:(ENRMStreamingEffectType)type
             duration:(CFTimeInterval)duration
               length:(NSUInteger)length
           startColor:(nullable RCTUIColor *)startColor
             endColor:(nullable RCTUIColor *)endColor;
@property (nonatomic, readonly) ENRMStreamingEffectType type;

/// `text` grew from `start` to `end` (UTF-16 offsets) at `time`.
- (void)noteArrivalIn:(NSString *)text from:(NSUInteger)start to:(NSUInteger)end at:(CFTimeInterval)time;
/// The stream ended at `time`: what still animates settles.
- (void)finishAt:(CFTimeInterval)time;
- (void)reset;

/// Whether the looks change from frame to frame at `time`.
- (BOOL)changesOverTimeAt:(CFTimeInterval)time;
/// The characters drawn differently at `time`; NSNotFound location when none.
- (NSRange)animatedRangeAt:(CFTimeInterval)time;
/// The color to draw the character at `index` with, given its own color, at `time`.
- (RCTUIColor *)colorForCharacterAtIndex:(NSUInteger)index ownColor:(RCTUIColor *)ownColor time:(CFTimeInterval)time;

@end

NS_ASSUME_NONNULL_END
