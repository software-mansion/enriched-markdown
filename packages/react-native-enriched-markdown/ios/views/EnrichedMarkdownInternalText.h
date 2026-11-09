#pragma once
#import "ENRMContextMenuTextView+macOS.h"
#import "ENRMSpoilerCapable.h"
#import "ENRMSpoilerOverlayView.h"
#import "ENRMUIKit.h"
#import "LinkTapUtils.h"
#import "StyleConfig.h"

@class RenderContext;
@class AccessibilityInfo;
@class ENRMAccessibilityLabels;
@class ENRMSpoilerOverlayManager;

@class ENRMRenderedSegment;

NS_ASSUME_NONNULL_BEGIN

@interface EnrichedMarkdownInternalText : RCTUIView <ENRMSpoilerCapable>

- (instancetype)initWithConfig:(StyleConfig *)config;

- (void)applyAttributedText:(NSMutableAttributedString *)text context:(RenderContext *)context;
// Replaces the shown text from `start` on with `tail`, keeping the selection and the layout before it.
- (void)applyAttributedTextPatch:(NSAttributedString *)tail from:(NSUInteger)start;

- (CGFloat)measureHeight:(CGFloat)maxWidth;
- (CGSize)measureSize:(CGFloat)maxWidth;

@property (nonatomic, readonly) ENRMPlatformTextView *textView;
@property (nonatomic, readonly) ENRMSpoilerOverlayManager *spoilerManager;
@property (nonatomic) ENRMSpoilerOverlay spoilerOverlay;

@property (nonatomic, strong, nullable) AccessibilityInfo *accessibilityInfo;
@property (nonatomic, strong, nullable) ENRMAccessibilityLabels *accessibilityLabels;

@property (nonatomic, strong) StyleConfig *config;

@property (nonatomic, assign) BOOL allowTrailingMargin;

@property (nonatomic, assign) CGFloat lastElementMarginBottom;

// The ENRMRenderResult revision shown, which a patch must be based on.
@property (nonatomic, assign) uint64_t renderedRevision;

/// Moves the drawn part of a long text to where it shows now (see ENRMTextViewport).
- (void)updateViewport;
/// Lays the text out again after the view joined a window.
- (void)refreshAfterWindowAttach;

#if TARGET_OS_OSX
- (void)setContextMenuProvider:(ENRMContextMenuProvider)provider;
#endif

@end

#ifdef __cplusplus
extern "C" {
#endif

// After reconciling `segments` into `views`: a view the reconciler kept shows its segment's text,
// under whatever revision it was given, so it takes the segment's. Returns the indices of the
// views that missed a patch, having no base for it, and need a full render.
NSIndexSet *ENRMSyncTextRevisions(NSArray<ENRMRenderedSegment *> *segments, NSArray<RCTUIView *> *views);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
