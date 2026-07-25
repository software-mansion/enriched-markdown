#import "ENRMLinkCoordinator.h"

@implementation ENRMLinkCoordinator {
  ENRMFormattingStore *_formattingStore;
  id<ENRMAutoLinkDetecting> _autoLinkDetector;
}

- (instancetype)initWithFormattingStore:(ENRMFormattingStore *)formattingStore
                       autoLinkDetector:(id<ENRMAutoLinkDetecting>)autoLinkDetector
{
  if (self = [super init]) {
    _formattingStore = formattingStore;
    _autoLinkDetector = autoLinkDetector;
  }
  return self;
}

- (NSString *)sanitizeURL:(NSString *)url
{
  NSString *result = [url stringByReplacingOccurrencesOfString:@"(" withString:@"%28"];
  return [result stringByReplacingOccurrencesOfString:@")" withString:@"%29"];
}

- (nullable ENRMFormattingRange *)linkAtPosition:(NSUInteger)position
{
  return [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:position];
}

- (BOOL)setLinkURL:(NSString *)url atCursor:(NSUInteger)cursor selection:(NSRange)selection
{
  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:cursor];

  if (activeLink != nil) {
    activeLink.url = url;
    [_autoLinkDetector clearAutoLinkInRange:activeLink.range];
    return YES;
  }

  if (selection.length > 0) {
    ENRMFormattingRange *linkRange = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink range:selection url:url];
    [_formattingStore addRange:linkRange];
    [_autoLinkDetector clearAutoLinkInRange:selection];
    return YES;
  }

  return NO;
}

- (void)addLinkWithURL:(NSString *)url start:(NSUInteger)start end:(NSUInteger)end
{
  if (start >= end) {
    return;
  }
  NSRange range = NSMakeRange(start, end - start);
  [_autoLinkDetector clearAutoLinkInRange:range];
  [_formattingStore addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                          range:range
                                                            url:[self sanitizeURL:url]]];
}

- (void)addLinkDirectWithURL:(NSString *)url start:(NSUInteger)start end:(NSUInteger)end
{
  if (start >= end) {
    return;
  }
  [_formattingStore addRange:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                          range:NSMakeRange(start, end - start)
                                                            url:url]];
}

- (BOOL)removeLinkAtPosition:(NSUInteger)position
{
  ENRMFormattingRange *activeLink = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:position];
  if (activeLink == nil) {
    return NO;
  }
  [_formattingStore removeRange:activeLink];
  return YES;
}

- (nullable ENRMFormattingRange *)linkRangeForDeletionAtPosition:(NSUInteger)position
{
  if (position == 0) {
    return nil;
  }
  return [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:position - 1];
}

@end
