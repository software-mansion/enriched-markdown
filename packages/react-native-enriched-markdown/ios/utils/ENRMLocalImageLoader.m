#import "ENRMLocalImageLoader.h"

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

RCTUIImage *_Nullable ENRMLoadLocalImage(NSString *url)
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

  RCTUIImage *image = imageName.length > 0 ? ENRMImageNamed(imageName) : nil;
  if (image == nil && filePath.length > 0) {
    image = ENRMImageAtPath(filePath);
  }
  return image;
}
