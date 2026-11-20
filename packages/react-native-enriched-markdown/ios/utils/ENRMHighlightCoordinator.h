#pragma once
#import "ENRMTextHighlight.h"
#import "ENRMUIKit.h"

NS_ASSUME_NONNULL_BEGIN

/// A block view that draws its own text, such as a code block or a table.
@protocol ENRMRenderedTextProviding <NSObject>
/// The text the block shows, for the `highlights` offsets to index into.
@property (nonatomic, readonly) NSString *renderedText;
/// "code" or "table".
@property (nonatomic, readonly) NSString *renderedTextKind;
@end

/// The part of the rendered text that one block shows.
@interface ENRMRenderedTextBlock : NSObject
@property (nonatomic, readonly) NSInteger start;
@property (nonatomic, readonly) NSInteger end;
/// "text", "code" or "table".
@property (nonatomic, readonly, copy) NSString *kind;
@end

/// Where one highlight shows, in host coordinates.
@interface ENRMHighlightRect : NSObject
@property (nonatomic, readonly) NSInteger index;
@property (nonatomic, readonly) CGRect rect;
@end

/**
 * Maps the `highlights` prop onto a markdown view's blocks. The rendered text
 * is the blocks' text in document order, joined with "\n". A text view gets its
 * part of each highlight drawn behind its glyphs; a block that draws its own
 * text gets a tint over the whole block.
 */
@interface ENRMHighlightCoordinator : NSObject

- (instancetype)initWithHost:(RCTUIView *)host NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/// Ranges in rendered-text offsets. Setting them repaints only what changes.
@property (nonatomic, copy) NSArray<ENRMTextHighlight *> *highlights;

/// Called with the highlights' boxes when they change.
@property (nonatomic, copy, nullable) void (^onLayout)(NSArray<ENRMHighlightRect *> *rects);

/// The blocks after a render, in document order: text views (ENRMPlatformTextView)
/// or views that adopt ENRMRenderedTextProviding. Others are skipped. Returns
/// whether the rendered text or its blocks changed.
- (BOOL)setBlockViews:(NSArray<RCTUIView *> *)blockViews;

@property (nonatomic, readonly, copy) NSString *renderedText;
@property (nonatomic, readonly, copy) NSArray<ENRMRenderedTextBlock *> *renderedBlocks;

/// Reports the boxes again if they moved. Call after the host lays out.
- (void)reportLayout;

/// Forgets the blocks, the highlights and what was reported.
- (void)reset;

@end

NS_ASSUME_NONNULL_END
