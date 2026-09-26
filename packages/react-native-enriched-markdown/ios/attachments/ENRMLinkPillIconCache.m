#import "ENRMLinkPillIconCache.h"
#import "ENRMImageDownloader.h"
#import "ENRMLocalImageLoader.h"
#if !TARGET_OS_OSX
#import <ImageIO/ImageIO.h>

UIImage *ENRMLoadLinkPillIcon(NSString *iconUri)
{
  NSString *path = ENRMResolveLocalImagePath(iconUri);
  if (!path)
    return nil;
  NSDictionary *attributes = [NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
  if (!attributes || ![attributes[NSFileType] isEqual:NSFileTypeRegular])
    return nil;
  NSString *key =
      [NSString stringWithFormat:@"%@|%.9f|%@", path, [attributes[NSFileModificationDate] timeIntervalSince1970],
                                 attributes[NSFileSize]];
  static NSCache<NSString *, UIImage *> *images;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    images = [NSCache new];
    images.countLimit = 64;
    images.totalCostLimit = 8 * 1024 * 1024;
  });
  UIImage *cached = [images objectForKey:key];
  if (cached)
    return cached;
  CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
  if (!source)
    return nil;
  NSDictionary *options = @{
    (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways : @YES,
    (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform : @YES,
    (__bridge NSString *)kCGImageSourceShouldCacheImmediately : @YES,
    (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize : @512,
  };
  CGImageRef decoded = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
  CFRelease(source);
  if (!decoded)
    return nil;
  UIImage *image = [UIImage imageWithCGImage:decoded];
  CGImageRelease(decoded);
  [images setObject:image forKey:key cost:ENRMImageByteCost(image)];
  return image;
}
#endif
