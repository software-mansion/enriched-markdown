#pragma once

#import "ENRMUIKit.h"
#import "RenderedMarkdownSegment.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * Placeholder stacked where a block replaced by a React child would have been.
 * It draws nothing and takes no touches; it only reserves `slotHeight`, the
 * height the shadow node measured for the child (published through state), so
 * the following segments shift exactly as far as the child Fabric mounts in the
 * host's slot layer.
 */
@interface ENRMBlockSlotSegmentView : RCTUIView

@property (nonatomic, copy) NSString *slotId;
@property (nonatomic, assign) ENRMBlockSlotKind kind;
@property (nonatomic, assign) CGFloat slotHeight;

/// The Fabric child mounted for this slot, so assistive technology reaches the
/// React content in document order even inside a nested container.
@property (nonatomic, weak, nullable) RCTUIView *mountedView;

- (CGFloat)measureHeight:(CGFloat)maxWidth;

@end

// The margins a slot takes from the block it stands in for: the image style's for
// an image paragraph, the video style's for a video, the paragraph's for a link.
static inline CGFloat ENRMBlockSlotMarginTop(ENRMBlockSlotKind kind, StyleConfig *config)
{
  switch (kind) {
    case ENRMBlockSlotKindVideo:
      return config.videoMarginTop;
    case ENRMBlockSlotKindLink:
      return config.paragraphMarginTop;
    default:
      return config.imageMarginTop;
  }
}

static inline CGFloat ENRMBlockSlotMarginBottom(ENRMBlockSlotKind kind, StyleConfig *config)
{
  switch (kind) {
    case ENRMBlockSlotKindVideo:
      return config.videoMarginBottom;
    case ENRMBlockSlotKindLink:
      return config.paragraphMarginBottom;
    default:
      return config.imageMarginBottom;
  }
}

#ifdef __cplusplus
extern "C" {
#endif

// Pushes the heights (by slot id) into every placeholder under segmentViews,
// recursing into nested containers. Returns YES when any height changed.
BOOL ENRMApplyBlockSlotHeights(NSArray<RCTUIView *> *segmentViews, NSDictionary<NSString *, NSNumber *> *heights);

// Points every placeholder under segmentViews at the mounted slot view of its id
// (nil when none), recursing into nested containers.
void ENRMBindBlockSlotViews(NSArray<RCTUIView *> *segmentViews, NSDictionary<NSString *, RCTUIView *> *views);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
