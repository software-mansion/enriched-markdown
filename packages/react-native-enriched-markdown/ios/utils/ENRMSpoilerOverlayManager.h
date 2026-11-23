#pragma once
#import "ENRMSpoilerOverlayView.h"
#import "ENRMUIKit.h"
#import "StyleConfig.h"

NS_ASSUME_NONNULL_BEGIN

@protocol ENRMSpoilerTextLayout <NSObject>
@property (nonatomic, readonly, nullable) NSTextStorage *textStorage;
@property (nonatomic, readonly, nullable) NSLayoutManager *layoutManager;
@property (nonatomic, readonly, nullable) NSTextContainer *textContainer;
@property (nonatomic, readonly, nullable) RCTUIView *spoilerOverlayHost;
@property (nonatomic, readonly) CGPoint spoilerTextOrigin;
@property (nonatomic, readonly) BOOL spoilerLayoutReady;
@optional
@property (nonatomic, readonly, nullable) RCTUIColor *spoilerBackgroundColor;
@end

@interface ENRMSpoilerOverlayManager : NSObject

@property (nonatomic) ENRMSpoilerOverlay spoilerOverlay;

- (instancetype)initWithLayout:(id<ENRMSpoilerTextLayout>)layout config:(StyleConfig *)config;
- (instancetype)initWithTextView:(ENRMPlatformTextView *)textView config:(StyleConfig *)config;

- (void)setNeedsUpdate;
- (void)updateIfNeeded;
- (void)removeOverlaysForCharRange:(NSRange)charRange;
- (void)removeAllOverlays;

@end

NS_ASSUME_NONNULL_END
