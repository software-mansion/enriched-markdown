#pragma once
#import "ENRMUIKit.h"

@class StyleConfig;
@class ENRMImageAttachment;

NS_ASSUME_NONNULL_BEGIN

/**
 * Adopted by component views that host markdown text. Notified when a block
 * image resolves its box height after loading (maxHeight/aspectRatio sizing),
 * so the view can drop stale cached measurements and request a height update.
 */
@protocol ENRMImageLayoutObserver
- (void)imageAttachmentDidResolveLayout;
@end

/**
 * Adopted by renderers that draw image attachments without a UITextView.
 * Observers are held weakly and notified on the main thread when processed
 * display content changes.
 */
@protocol ENRMImageDisplayObserver
- (void)imageAttachmentDidUpdateDisplay:(ENRMImageAttachment *)attachment;
@end

/**
 * Custom NSTextAttachment for rendering markdown images.
 * Images are loaded asynchronously and scaled dynamically based on text container width.
 * Supports inline and block images with custom height and border radius from config.
 */
@interface ENRMImageAttachment : NSTextAttachment

@property (nonatomic, readonly) NSString *imageURL;
@property (nonatomic, readonly) BOOL isInline;

+ (instancetype)attachmentForURL:(NSString *)imageURL config:(StyleConfig *)config isInline:(BOOL)isInline;

+ (void)clearAttachmentRegistry;

+ (NSCache<NSString *, RCTUIImage *> *)originalImageCache;
+ (NSCache<NSString *, RCTUIImage *> *)processedImageCache;

- (void)addDisplayObserver:(id<ENRMImageDisplayObserver>)observer;
- (void)removeDisplayObserver:(id<ENRMImageDisplayObserver>)observer;

@end

NS_ASSUME_NONNULL_END
