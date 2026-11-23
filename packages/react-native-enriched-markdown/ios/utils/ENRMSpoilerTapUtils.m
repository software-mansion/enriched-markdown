#import "ENRMSpoilerTapUtils.h"
#import "ENRMSpoilerOverlayManager.h"
#import "ENRMTextHitTest.h"

NSString *const SpoilerAttributeName = @"Spoiler";
NSString *const SpoilerOriginalColorAttributeName = @"SpoilerOriginalColor";

// Expands outward because internal formatting can split the attribute into multiple runs.
static NSRange expandSpoilerRange(NSAttributedString *textStorage, NSUInteger index)
{
  NSRange run;
  [textStorage attribute:SpoilerAttributeName atIndex:index effectiveRange:&run];

  NSUInteger start = run.location;
  NSUInteger end = NSMaxRange(run);
  NSUInteger length = textStorage.length;

  while (start > 0) {
    if (![textStorage attribute:SpoilerAttributeName atIndex:start - 1 effectiveRange:&run])
      break;
    start = run.location;
  }

  while (end < length) {
    if (![textStorage attribute:SpoilerAttributeName atIndex:end effectiveRange:&run])
      break;
    end = NSMaxRange(run);
  }

  return NSMakeRange(start, end - start);
}

void ENRMRestoreSpoilerTextColors(NSMutableAttributedString *textStorage, NSRange range)
{
  [textStorage beginEditing];
  [textStorage enumerateAttribute:SpoilerOriginalColorAttributeName
                          inRange:range
                          options:0
                       usingBlock:^(id value, NSRange subRange, BOOL *stop) {
                         if (!value)
                           return;
                         if (value == [NSNull null]) {
                           [textStorage removeAttribute:NSForegroundColorAttributeName range:subRange];
                         } else {
                           [textStorage addAttribute:NSForegroundColorAttributeName value:value range:subRange];
                         }
                         [textStorage removeAttribute:SpoilerOriginalColorAttributeName range:subRange];
                       }];
  [textStorage endEditing];
}

void ENRMConcealSpoilers(NSMutableAttributedString *text)
{
  NSRange whole = NSMakeRange(0, text.length);
  [text enumerateAttribute:SpoilerAttributeName
                   inRange:whole
                   options:0
                usingBlock:^(id spoiler, NSRange spoilerRange, BOOL *stop) {
                  if (!spoiler)
                    return;
                  [text enumerateAttribute:SpoilerOriginalColorAttributeName
                                   inRange:spoilerRange
                                   options:0
                                usingBlock:^(id saved, NSRange range, BOOL *innerStop) {
                                  if (saved)
                                    return;
                                  [text enumerateAttribute:NSForegroundColorAttributeName
                                                   inRange:range
                                                   options:0
                                                usingBlock:^(id color, NSRange colorRange, BOOL *colorStop) {
                                                  [text addAttribute:SpoilerOriginalColorAttributeName
                                                               value:color ?: [NSNull null]
                                                               range:colorRange];
                                                }];
                                  [text addAttribute:NSForegroundColorAttributeName
                                               value:[RCTUIColor colorWithWhite:0 alpha:0]
                                               range:range];
                                }];
                }];
}

void ENRMSetTextColorRespectingSpoilers(NSMutableAttributedString *text, RCTUIColor *color, NSRange range)
{
  [text enumerateAttribute:SpoilerOriginalColorAttributeName
                   inRange:range
                   options:0
                usingBlock:^(id saved, NSRange subRange, BOOL *stop) {
                  if (saved) {
                    [text addAttribute:SpoilerOriginalColorAttributeName value:color ?: [NSNull null] range:subRange];
                  } else if (color) {
                    [text addAttribute:NSForegroundColorAttributeName value:color range:subRange];
                  } else {
                    [text removeAttribute:NSForegroundColorAttributeName range:subRange];
                  }
                }];
}

void ENRMRevealSpoilerInRange(NSMutableAttributedString *text, NSRange range)
{
  [text beginEditing];
  [text removeAttribute:SpoilerAttributeName range:range];
  ENRMRestoreSpoilerTextColors(text, range);
  [text endEditing];
}

NSRange ENRMRevealSpoilerAtIndex(NSMutableAttributedString *text, NSUInteger index)
{
  if (index >= text.length || ![text attribute:SpoilerAttributeName atIndex:index effectiveRange:NULL])
    return NSMakeRange(NSNotFound, 0);
  NSRange fullRange = expandSpoilerRange(text, index);
  ENRMRevealSpoilerInRange(text, fullRange);
  return fullRange;
}

BOOL handleSpoilerTap(ENRMPlatformTextView *textView, ENRMTapRecognizer *recognizer,
                      ENRMSpoilerOverlayManager *spoilerManager)
{
  NSUInteger characterIndex = ENRMCharacterIndexForTap(textView, recognizer);
  if (characterIndex == NSNotFound)
    return NO;

  NSRange fullRange = ENRMRevealSpoilerAtIndex(textView.textStorage, characterIndex);
  if (fullRange.location == NSNotFound)
    return NO;

  [spoilerManager removeOverlaysForCharRange:fullRange];
  return YES;
}
