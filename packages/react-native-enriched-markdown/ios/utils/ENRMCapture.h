#pragma once
#import "ENRMUIKit.h"

#if !TARGET_OS_OSX
NS_ASSUME_NONNULL_BEGIN

/// What a capture shows of a participant's content.
typedef NS_ENUM(NSInteger, ENRMCaptureCoverage) {
  /// None of it: the participant's end is not called.
  ENRMCaptureCoverageNone,
  /// Only what was drawn already.
  ENRMCaptureCoverageDrawn,
  /// Content drawn for the capture, which the capture must commit.
  ENRMCaptureCoverageAdded,
};

/// Content that draws only near the screen (ENRMTextTiles, a document's block bitmaps) and draws the
/// rest for a capture of it.
@protocol ENRMCaptureParticipant <NSObject>
/// A capture of `view` is starting: draws the part of the content it shows.
- (ENRMCaptureCoverage)beginCaptureOfView:(UIView *)view;
/// The capture ended: drops what was drawn for it.
- (void)endCapture;
@end

/// Calls `participant` around drawViewHierarchyInRect: captures and snapshot views from now on, which
/// it hooks the first time. They render through the render server and ask the views nothing on the
/// way, so without the hook a capture shows only what is drawn near the screen.
FOUNDATION_EXTERN void ENRMCaptureAddParticipant(id<ENRMCaptureParticipant> participant);

NS_ASSUME_NONNULL_END
#endif
