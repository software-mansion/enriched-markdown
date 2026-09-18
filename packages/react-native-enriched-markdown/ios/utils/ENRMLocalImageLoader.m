#import "ENRMLocalImageLoader.h"
#import "ENRMAnimatedImage.h"

static NSString *_Nullable ENRMBundleRelativePath(NSString *path)
{
  NSString *bundlePath = [[NSBundle mainBundle] resourcePath];
  if (bundlePath == nil || ![path hasPrefix:bundlePath]) {
    return nil;
  }
  NSString *relative = [path substringFromIndex:bundlePath.length];
  return [relative hasPrefix:@"/"] ? [relative substringFromIndex:1] : relative;
}

static RCTUIImage *_Nullable ENRMImageNamed(NSString *name)
{
  return [RCTUIImage imageNamed:name];
}

static RCTUIImage *_Nullable ENRMImageAtPath(NSString *path)
{
  if (path.pathExtension.length == 0) {
    path = [path stringByAppendingPathExtension:@"png"];
  }
#if !TARGET_OS_OSX
  return [RCTUIImage imageWithContentsOfFile:path];
#else
  return [[RCTUIImage alloc] initWithContentsOfFile:path];
#endif
}

BOOL ENRMIsLocalImageURL(NSString *url)
{
  if ([url hasPrefix:@"file://"]) {
    return YES;
  }
  NSURL *parsed = [NSURL URLWithString:url];
  return parsed == nil || parsed.scheme.length == 0;
}

static void ENRMResolveLocalImageSource(NSString *url, NSString *_Nullable *filePathOut,
                                        NSString *_Nullable *imageNameOut)
{
  NSString *filePath = nil;
  NSString *imageName = nil;

  if ([url hasPrefix:@"file://"]) {
    NSURL *fileURL = [NSURL URLWithString:url];
    if (fileURL.fileURL) {
      filePath = @(fileURL.fileSystemRepresentation);
    } else {
      NSString *stripped = [url substringFromIndex:@"file://".length];
      filePath = [stripped stringByRemovingPercentEncoding] ?: stripped;
    }
    imageName = ENRMBundleRelativePath(filePath);
  } else {
    NSString *decoded = [url stringByRemovingPercentEncoding] ?: url;
    if (decoded.absolutePath) {
      filePath = decoded;
    } else {
      imageName = decoded;
      filePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:decoded];
    }
  }

  *filePathOut = filePath;
  *imageNameOut = imageName;
}

RCTUIImage *_Nullable ENRMLoadLocalImage(NSString *url)
{
  NSString *filePath = nil;
  NSString *imageName = nil;
  ENRMResolveLocalImageSource(url, &filePath, &imageName);

  RCTUIImage *image = imageName.length > 0 ? ENRMImageNamed(imageName) : nil;
  if (image == nil && filePath.length > 0) {
    image = ENRMImageAtPath(filePath);
  }
  return image;
}

ENRMAnimatedImage *_Nullable ENRMLoadLocalAnimatedImage(NSString *url)
{
  NSString *filePath = nil;
  NSString *imageName = nil;
  ENRMResolveLocalImageSource(url, &filePath, &imageName);
  if (filePath.length == 0)
    return nil;

  // Skip the read for other explicit extensions; an extension-less path is tried as .gif.
  NSString *extension = filePath.pathExtension.lowercaseString;
  if (extension.length == 0) {
    filePath = [filePath stringByAppendingPathExtension:@"gif"];
  } else if (![extension isEqualToString:@"gif"]) {
    return nil;
  }

  // Not memory-mapped: the bytes outlive the file in the animated cache.
  NSData *data = [NSData dataWithContentsOfFile:filePath];
  if (!data)
    return nil;
  return [ENRMAnimatedImage animatedImageWithData:data];
}
