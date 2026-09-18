#import "ENRMImageDownloader.h"
#import "ENRMAnimatedImage.h"
#import "ENRMImageAttachment.h"
#import "ENRMLocalImageLoader.h"
#import <CommonCrypto/CommonDigest.h>
#include <TargetConditionals.h>

static const NSUInteger kDiskCacheMemoryCapacity = 10 * 1024 * 1024;
static const NSUInteger kDiskCacheDiskCapacity = 100 * 1024 * 1024;

static inline NSUInteger ENRMImageByteCost(RCTUIImage *image)
{
  CGImageRef cgImage = image.CGImage;
  if (!cgImage)
    return 0;
  return CGImageGetBytesPerRow(cgImage) * CGImageGetHeight(cgImage);
}

// An animated entry retains the encoded bytes plus one decoded poster frame.
static inline NSUInteger ENRMAnimatedImageCost(ENRMAnimatedImage *animated)
{
  return animated.data.length + ENRMImageByteCost(animated.firstFrame);
}

NSString *ENRMImageCacheKey(NSString *url, NSDictionary<NSString *, NSString *> *headers)
{
  if (headers.count == 0) {
    return url;
  }
  NSArray<NSString *> *names = [headers.allKeys sortedArrayUsingSelector:@selector(compare:)];
  NSMutableArray<NSString *> *pairs = [NSMutableArray arrayWithCapacity:names.count];
  for (NSString *name in names) {
    [pairs addObject:[NSString stringWithFormat:@"%@:%@", name, headers[name]]];
  }
  NSString *joined = [pairs componentsJoinedByString:@"\n"];
  NSData *data = [joined dataUsingEncoding:NSUTF8StringEncoding];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *hash = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [hash appendFormat:@"%02x", digest[i]];
  }
  return [NSString stringWithFormat:@"%@|%@", url, hash];
}

@implementation ENRMImageDownloader {
  NSURLSession *_session;
  NSMutableDictionary<NSString *, NSMutableArray<ENRMImageDownloadCompletion> *> *_inFlightRequests;
}

+ (instancetype)shared
{
  static ENRMImageDownloader *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{ instance = [[ENRMImageDownloader alloc] init]; });
  return instance;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.URLCache = [[NSURLCache alloc] initWithMemoryCapacity:kDiskCacheMemoryCapacity
                                                    diskCapacity:kDiskCacheDiskCapacity
                                                    directoryURL:nil];
    config.requestCachePolicy = NSURLRequestReturnCacheDataElseLoad;
    config.timeoutIntervalForRequest = 15;
    config.timeoutIntervalForResource = 30;
    _session = [NSURLSession sessionWithConfiguration:config];
    _inFlightRequests = [NSMutableDictionary dictionary];
  }
  return self;
}

- (void)downloadURL:(NSString *)url
            headers:(NSDictionary<NSString *, NSString *> *)headers
         completion:(ENRMImageDownloadCompletion)completion
{
  if (url.length == 0) {
    completion(nil, nil);
    return;
  }

  BOOL isLocal = ENRMIsLocalImageURL(url);
  NSString *cacheKey = isLocal ? url : ENRMImageCacheKey(url, headers);

  // Separate caches so an eviction never leaves a GIF's poster without its frames.
  ENRMAnimatedImage *cachedAnimated = [[ENRMImageAttachment animatedImageCache] objectForKey:cacheKey];
  if (cachedAnimated) {
    completion(cachedAnimated.firstFrame, cachedAnimated);
    return;
  }

  RCTUIImage *cached = [[ENRMImageAttachment originalImageCache] objectForKey:cacheKey];
  if (cached) {
    completion(cached, nil);
    return;
  }

  if (isLocal) {
    ENRMAnimatedImage *localAnimated = ENRMLoadLocalAnimatedImage(url);
    if (localAnimated) {
      [[ENRMImageAttachment animatedImageCache] setObject:localAnimated
                                                   forKey:cacheKey
                                                     cost:ENRMAnimatedImageCost(localAnimated)];
      completion(localAnimated.firstFrame, localAnimated);
      return;
    }
    RCTUIImage *local = ENRMLoadLocalImage(url);
    if (local) {
      [[ENRMImageAttachment originalImageCache] setObject:local forKey:cacheKey cost:ENRMImageByteCost(local)];
    }
    completion(local, nil);
    return;
  }

  @synchronized(_inFlightRequests) {
    NSMutableArray *existing = _inFlightRequests[cacheKey];
    if (existing) {
      [existing addObject:completion];
      return;
    }
    _inFlightRequests[cacheKey] = [NSMutableArray arrayWithObject:completion];
  }

  NSURL *nsURL = [NSURL URLWithString:url];
  if (!nsURL) {
    [self dispatchCallbacksForKey:cacheKey image:nil animated:nil];
    return;
  }

  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsURL];
  [headers enumerateKeysAndObjectsUsingBlock:^(NSString *name, NSString *value, BOOL *stop) {
    [request setValue:value forHTTPHeaderField:name];
  }];

  [[_session dataTaskWithRequest:request
               completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                 NSInteger status = [response isKindOfClass:[NSHTTPURLResponse class]]
                                        ? ((NSHTTPURLResponse *)response).statusCode
                                        : 200;
                 if (!data || error || status < 200 || status >= 300) {
                   if (status < 200 || status >= 300) {
                     NSLog(@"[EnrichedMarkdown] Image request failed with HTTP %ld: %@", (long)status, url);
                   }
                   [self dispatchCallbacksForKey:cacheKey image:nil animated:nil];
                   return;
                 }

                 ENRMAnimatedImage *animated = [ENRMAnimatedImage animatedImageWithData:data];
                 if (animated) {
                   [[ENRMImageAttachment animatedImageCache] setObject:animated
                                                                forKey:cacheKey
                                                                  cost:ENRMAnimatedImageCost(animated)];
                   [self dispatchCallbacksForKey:cacheKey image:animated.firstFrame animated:animated];
                   return;
                 }

#if !TARGET_OS_OSX
                 RCTUIImage *image = [RCTUIImage imageWithData:data];
#else
        RCTUIImage *image = [[RCTUIImage alloc] initWithData:data];
#endif

                 if (image) {
                   [[ENRMImageAttachment originalImageCache] setObject:image
                                                                forKey:cacheKey
                                                                  cost:ENRMImageByteCost(image)];
                 }

                 [self dispatchCallbacksForKey:cacheKey image:image animated:nil];
               }] resume];
}

- (void)dispatchCallbacksForKey:(NSString *)cacheKey
                          image:(RCTUIImage *_Nullable)image
                       animated:(ENRMAnimatedImage *_Nullable)animated
{
  NSArray<ENRMImageDownloadCompletion> *callbacks;
  @synchronized(_inFlightRequests) {
    callbacks = [_inFlightRequests[cacheKey] copy];
    [_inFlightRequests removeObjectForKey:cacheKey];
  }

  if (!callbacks)
    return;

  dispatch_async(dispatch_get_main_queue(), ^{
    for (ENRMImageDownloadCompletion cb in callbacks) {
      cb(image, animated);
    }
  });
}

@end
