#import "ENRMTextHitTest.h"

NSUInteger ENRMCharacterIndexAtPoint(ENRMPlatformTextView *textView, CGPoint point)
{
  NSLayoutManager *layoutManager = textView.layoutManager;
  CGPoint adjusted = CGPointMake(point.x - textView.textContainerInset.left, point.y - textView.textContainerInset.top);

  NSUInteger index = [layoutManager characterIndexForPoint:adjusted
                                           inTextContainer:textView.textContainer
                  fractionOfDistanceBetweenInsertionPoints:NULL];

  NSUInteger length = ENRMGetAttributedText(textView).length;
  return index < length ? index : NSNotFound;
}

NSUInteger ENRMCharacterIndexAtPointStrict(ENRMPlatformTextView *textView, CGPoint point)
{
  NSUInteger index = ENRMCharacterIndexAtPoint(textView, point);
  if (index == NSNotFound) {
    return NSNotFound;
  }

  // characterIndexForPoint snaps to the nearest character, so a tap in empty
  // space after a line's last word still resolves to a real index. Reject the
  // hit unless the point is inside the used portion of the character's line
  // fragment — mirrors the Android bounds check in charOffsetAt.
  NSLayoutManager *layoutManager = textView.layoutManager;
  CGPoint adjusted = CGPointMake(point.x - textView.textContainerInset.left, point.y - textView.textContainerInset.top);
  NSUInteger glyphIndex = [layoutManager glyphIndexForCharacterAtIndex:index];
  CGRect lineRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:NULL];
  return CGRectContainsPoint(lineRect, adjusted) ? index : NSNotFound;
}

NSUInteger ENRMCharacterIndexForTap(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer)
{
  CGPoint location = [recognizer locationInView:textView];
  return ENRMCharacterIndexAtPoint(textView, location);
}
