#pragma once
#import "ENRMUIKit.h"
#import "LastElementUtils.h"
#import "StyleConfig.h"
#import "TextViewLayoutManager.h"
#import <React/RCTUtils.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

static inline void ENRMAttachLayoutManager(ENRMPlatformTextView *textView, StyleConfig *_Nullable config)
{
  NSLayoutManager *layoutManager = textView.layoutManager;
  if (layoutManager == nil) {
    return;
  }
  layoutManager.allowsNonContiguousLayout = NO;
  object_setClass(layoutManager, [TextViewLayoutManager class]);
  if (config != nil) {
    [layoutManager setValue:config forKey:@"config"];
  }
}

static inline void ENRMDetachLayoutManager(ENRMPlatformTextView *textView)
{
  NSLayoutManager *layoutManager = textView.layoutManager;
  if (layoutManager != nil && [object_getClass(layoutManager) isEqual:[TextViewLayoutManager class]]) {
    [layoutManager setValue:nil forKey:@"config"];
    object_setClass(layoutManager, [NSLayoutManager class]);
  }
}

/// Returns maxWidth for soft-wrapped content, otherwise the tight width of its
/// lines, or fallbackWidth when no line fragment was laid out. The tight width
/// adds each line's head and tail indent to its used rect, which TextKit leaves
/// out; lists and code blocks re-wrap without them.
static inline CGFloat ENRMContentWidth(NSLayoutManager *layoutManager, CGFloat maxWidth, CGFloat fallbackWidth)
{
  CGFloat tightWidth = 0;
  NSTextStorage *storage = layoutManager.textStorage;
  NSString *string = storage.string;
  NSCharacterSet *newlines = [NSCharacterSet newlineCharacterSet];
  NSUInteger glyphCount = [layoutManager numberOfGlyphs];
  BOOL startsParagraph = YES;
  NSUInteger glyphIndex = 0;
  while (glyphIndex < glyphCount) {
    NSRange lineGlyphRange;
    CGRect usedRect = [layoutManager lineFragmentUsedRectForGlyphAtIndex:glyphIndex effectiveRange:&lineGlyphRange];
    if (lineGlyphRange.location == NSNotFound || NSMaxRange(lineGlyphRange) <= glyphIndex) {
      break; // past a numberOfLines clamp: no fragment holds these glyphs
    }
    NSRange lineCharRange = [layoutManager characterRangeForGlyphRange:lineGlyphRange actualGlyphRange:NULL];
    if (lineCharRange.length == 0) {
      break;
    }

    NSParagraphStyle *style = [storage attribute:NSParagraphStyleAttributeName
                                         atIndex:lineCharRange.location
                                  effectiveRange:NULL];
    CGFloat headIndent = startsParagraph ? style.firstLineHeadIndent : style.headIndent;
    CGFloat tailInset = style.tailIndent < 0 ? -style.tailIndent : 0;
    tightWidth = MAX(tightWidth, usedRect.size.width + headIndent + tailInset);
    if (tightWidth >= maxWidth) {
      return maxWidth;
    }

    BOOL endsParagraph = [newlines characterIsMember:[string characterAtIndex:NSMaxRange(lineCharRange) - 1]];
    NSUInteger nextGlyphIndex = NSMaxRange(lineGlyphRange);
    if (nextGlyphIndex < glyphCount && !endsParagraph) {
      return maxWidth; // soft wrap
    }
    startsParagraph = endsParagraph;
    glyphIndex = nextGlyphIndex;
  }
  return tightWidth > 0 ? tightWidth : fallbackWidth;
}

/// Turns a raw TextKit layout pass into the final measured size. Shared by
/// the view-backed path (`ENRMMeasureMarkdownText`) and the view-free path
/// (`ENRMMeasureMarkdownViewFree`) so both measure with one algorithm.
///
/// Steps, in order:
/// - Soft-wrapped content reports maxWidth: a tight width would let flexShrink
///   narrow the view, re-wrapping it and mismatching the measured height.
///   Content broken only by explicit newlines keeps its tight width.
/// - Optionally subtract the extra line fragment (iOS counts a trailing
///   newline's empty line fragment into usedRect). Read-only markdown passes
///   YES; text input passes NO so trailing newlines keep a blank line (RN Text
///   parity).
/// - Add code-block padding when the last element is a code block, and the
///   trailing margin when enabled.
/// - Round up to the pixel grid of `scale` (pass `RCTScreenScale()` on main;
///   off-main callers must pass `LayoutContext::pointScaleFactor` instead —
///   `RCTScreenScale()` dispatch_syncs to main on first use, which the
///   measure path must never do, see issue #550).
static inline CGSize ENRMFinalizeMeasuredTextSize(ENRMTextLayoutResult layout, NSLayoutManager *layoutManager,
                                                  CGFloat maxWidth, StyleConfig *config, BOOL allowTrailingMargin,
                                                  CGFloat lastElementMarginBottom, BOOL subtractExtraLineFragment,
                                                  CGFloat scale)
{
  CGFloat measuredWidth = ENRMContentWidth(layoutManager, maxWidth, layout.usedRect.size.width);
  CGFloat measuredHeight = layout.usedRect.size.height;

  if (subtractExtraLineFragment && !CGRectIsEmpty(layout.extraLineFragmentRect)) {
    measuredHeight -= layout.extraLineFragmentRect.size.height;
  }

  if (isLastElementCodeBlock(layoutManager.textStorage)) {
    measuredHeight += [config codeBlockPadding];
  }

  if (allowTrailingMargin && lastElementMarginBottom > 0) {
    measuredHeight += lastElementMarginBottom;
  }

  return CGSizeMake(ceil(measuredWidth * scale) / scale, ceil(measuredHeight * scale) / scale);
}

static inline CGSize ENRMMeasureMarkdownText(ENRMPlatformTextView *textView, CGFloat maxWidth, StyleConfig *config,
                                             BOOL allowTrailingMargin, CGFloat lastElementMarginBottom)
{
  NSAttributedString *text = ENRMGetAttributedText(textView);
  if (text.length == 0) {
    return CGSizeZero;
  }

  ENRMTextLayoutResult layout = ENRMMeasureTextLayout(textView, maxWidth);
  return ENRMFinalizeMeasuredTextSize(layout, textView.layoutManager, maxWidth, config, allowTrailingMargin,
                                      lastElementMarginBottom, YES, RCTScreenScale());
}

NS_ASSUME_NONNULL_END
