#pragma once

#import "ENRMUIKit.h"

@class ENRMSpoilerOverlayManager;

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

extern NSString *const SpoilerAttributeName;
extern NSString *const SpoilerOriginalColorAttributeName;

BOOL handleSpoilerTap(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer,
                      ENRMSpoilerOverlayManager *spoilerManager);

void ENRMRestoreSpoilerTextColors(NSMutableAttributedString *textStorage, NSRange range);

NSRange ENRMRevealSpoilerAtIndex(NSMutableAttributedString *text, NSUInteger index);

void ENRMRevealSpoilerInRange(NSMutableAttributedString *text, NSRange range);

void ENRMConcealSpoilers(NSMutableAttributedString *text);

void ENRMSetTextColorRespectingSpoilers(NSMutableAttributedString *text, RCTUIColor *_Nullable color, NSRange range);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
