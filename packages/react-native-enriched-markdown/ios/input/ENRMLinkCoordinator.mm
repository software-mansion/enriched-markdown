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

- (nullable ENRMFormattingRange *)linkForSelection:(NSRange)selection
{
  ENRMFormattingRange *link = [_formattingStore rangeOfType:ENRMInputStyleTypeLink
                                         containingPosition:selection.location];
  if (link == nil && selection.length == 0 && selection.location > 0) {
    link = [_formattingStore rangeOfType:ENRMInputStyleTypeLink containingPosition:selection.location - 1];
  }
  return link;
}

- (BOOL)setLinkURL:(NSString *)url forSelection:(NSRange)selection
{
  ENRMFormattingRange *activeLink = [self linkForSelection:selection];

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

- (BOOL)removeLinkForSelection:(NSRange)selection
{
  ENRMFormattingRange *activeLink = [self linkForSelection:selection];
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
