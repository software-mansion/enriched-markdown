#pragma once
#import "ENRMUIKit.h"

@class ENRMAnimatedImage;

NS_ASSUME_NONNULL_BEGIN

/// `image` is the decoded still (for a GIF: its first frame). `animated` is
/// non-nil only for multi-frame GIFs; it shares the same cache identity.
typedef void (^ENRMImageDownloadCompletion)(RCTUIImage *_Nullable image, ENRMAnimatedImage *_Nullable animated);

/**
 * Cache identity for a remote image request. Returns the URL itself when no
 * headers are set; otherwise appends a SHA-256 digest of the sorted header
 * pairs, so the same URL fetched with different headers is cached and
 * deduplicated separately without embedding header values in the key.
 */
NSString *ENRMImageCacheKey(NSString *url, NSDictionary<NSString *, NSString *> *_Nullable headers);

@interface ENRMImageDownloader : NSObject

+ (instancetype)shared;

- (void)downloadURL:(NSString *)url
            headers:(nullable NSDictionary<NSString *, NSString *> *)headers
         completion:(ENRMImageDownloadCompletion)completion;

@end

NS_ASSUME_NONNULL_END
