#import "LinkTapUtils.h"
#import "ENRMSpoilerTapUtils.h"
#import "ENRMTextHitTest.h"

NSString *_Nullable linkURLAtTapLocation(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer)
{
  NSUInteger characterIndex = ENRMCharacterIndexForTap(textView, recognizer);
  if (characterIndex == NSNotFound)
    return nil;

  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  return [attrText attribute:@"linkURL" atIndex:characterIndex effectiveRange:NULL];
}

NSString *_Nullable linkURLAtRange(ENRMPlatformTextView *textView, NSRange characterRange)
{
  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  if (characterRange.location >= attrText.length) {
    return nil;
  }
  return [attrText attribute:@"linkURL" atIndex:characterRange.location effectiveRange:NULL];
}

NSDictionary<NSString *, NSString *> *_Nullable imageAtTapLocation(ENRMPlatformTextView *textView,
                                                                   ENRMTapRecognizer *recognizer)
{
  NSUInteger characterIndex = ENRMCharacterIndexForTap(textView, recognizer);
  if (characterIndex == NSNotFound)
    return nil;

  NSAttributedString *attrText = ENRMGetAttributedText(textView);
  if ([attrText attribute:@"linkURL" atIndex:characterIndex effectiveRange:NULL] != nil)
    return nil;

  NSString *url = [attrText attribute:@"imageURL" atIndex:characterIndex effectiveRange:NULL];
  if (!url)
    return nil;

  NSString *altText = [attrText attribute:@"imageAltText" atIndex:characterIndex effectiveRange:NULL];
  return @{@"url" : url, @"altText" : altText ?: @""};
}

BOOL isPointOnInteractiveElement(ENRMPlatformTextView *textView, CGPoint point, BOOL includeImages)
{
  NSUInteger charIndex = ENRMCharacterIndexAtPoint(textView, point);
  if (charIndex == NSNotFound)
    return NO;

  NSDictionary *attrs = [ENRMGetAttributedText(textView) attributesAtIndex:charIndex effectiveRange:NULL];
  if (attrs[@"linkURL"] != nil || [attrs[@"TaskItem"] boolValue] || attrs[SpoilerAttributeName] != nil)
    return YES;

  return includeImages && attrs[@"imageURL"] != nil;
}
