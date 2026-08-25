#pragma once

#import "ENRMCodeBlockContainerView.h"
#import "ENRMFeatureFlags.h"
#import "ENRMMarkdownParser.h"
#import "ENRMTextRenderer.h"
#import "ENRMTextViewSetup.h"
#import "ImageRequestHeaderUtils.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderedMarkdownSegment.h"
#import "SegmentRenderer.h"
#import "StreamingMarkdownFilter.h"
#import "StylePropsUtils.h"
#import "TableContainerView.h"
#include <type_traits>
#if ENRICHED_MARKDOWN_MATH
#import "ENRMMathContainerView.h"
#endif

/**
 * View-free markdown measurement (issue #550).
 *
 * The previous measurement path built throwaway component views on the main
 * thread via `dispatch_sync` — a deadlock when `measureContent` runs under
 * RN's locked commit fallback while a main-thread committer (Reanimated) is
 * blocked on the same mutex, and a serialization bottleneck (streaming jank)
 * even when it doesn't deadlock.
 *
 * These pipelines measure on the calling thread with no view and no
 * main-thread dependency, mirroring RN core's `RCTTextLayoutManager` (which
 * measures every `<Text>` this way in production) and this library's own
 * Android `MeasurementStore`:
 *
 * - `ENRMMeasureMarkdownViewFree` (EnrichedMarkdownText): parse (md4c) →
 *   `ENRMRenderASTNodes` (the SAME renderer the visible view uses, so
 *   measured layout ≡ rendered layout) → a fresh per-call
 *   NSTextStorage/NSLayoutManager/NSTextContainer stack → shared finalize.
 * - `ENRMMeasureSegmentedMarkdownViewFree` (EnrichedMarkdown): the iOS
 *   counterpart of Android's `MeasurementStore.measureAndCacheSplit` — split
 *   the AST into segments via the same `ENRMRenderSegmentsFromAST` the view
 *   uses, then walk them exactly like the view's
 *   `computeSegmentLayoutForWidth:`: text via the TextKit stack, tables via
 *   `+[TableContainerView measureHeightForTableNode:…]`, math via
 *   `+[ENRMMathContainerView measureHeightForLatex:…]`, with the same
 *   margin arithmetic.
 *
 * TextKit objects are thread-CONFINED, not main-thread-only: safe off main as
 * long as one thread owns a given stack (Apple-sanctioned; the
 * Texture/AsyncDisplayKit pattern). Allocating the stack per call — exactly
 * what `RCTTextLayoutManager` does — makes confinement trivially true.
 * `boundingRectWithSize:` (tables, math fallback) is documented thread-safe.
 *
 * Ambient-state rules for this path:
 * - Font scale comes in as a parameter (from `LayoutContext::fontSizeMultiplier`),
 *   never from `RCTFontSizeMultiplier()` (UIKit read).
 * - Pixel rounding uses `LayoutContext::pointScaleFactor`, never
 *   `RCTScreenScale()` (dispatch_syncs to main on first use).
 * - The resolved layout direction comes from `LayoutConstraints::layoutDirection`,
 *   never from `RCTI18nUtil`.
 * - The geometry config must match the visible view's
 *   (`ENRMConfigureMarkdownTextView`): zero insets, `lineFragmentPadding = 0`,
 *   `allowsNonContiguousLayout = NO`. The view's custom `TextViewLayoutManager`
 *   subclass only draws backgrounds and does not affect geometry.
 * - Each entry point drains its own `@autoreleasepool`. The calling JS/layout
 *   thread has no runloop draining pools, and a full measure autoreleases
 *   thousands of objects (AST, attributed string, TextKit stack, fonts) — the
 *   old main-thread path silently leaned on the main runloop's per-cycle
 *   drain, and without a local pool sustained re-measurement accumulates
 *   until jetsam kills the app.
 *
 * RaTeX concurrency (math segments and lazily-measured inline math
 * attachments now parse on the calling thread, possibly concurrently with the
 * render thread): verified safe against RaTeX sources. The Swift engine is
 * stateless per call, font registration is NSLock-guarded and idempotent
 * (RaTeXFontLoader), the FFI's last-error slot is thread_local, the Rust
 * core's only statics are immutable OnceLock/LazyLock tables, and renderer
 * font caches are per-call locals.
 */

template <typename Md4cFlagsT> static inline ENRMMd4cFlags *ENRMMd4cFlagsFromProps(const Md4cFlagsT &props)
{
  ENRMMd4cFlags *flags = [ENRMMd4cFlags defaultFlags];
  flags.underline = props.underline;
  flags.superscript = props.superscript;
  flags.subscript = props.subscript;
  flags.latexMath = props.latexMath;
  flags.highlight = props.highlight;
  flags.hardSoftBreaks = props.hardSoftBreaks;
  return flags;
}

/**
 * Builds a StyleConfig from props alone, replicating the mock-view recipe
 * field for field: a fresh config receives the props' style diffed against a
 * default-constructed style struct (the mock view's `updateProps
 * oldProps:nullptr` applied the same diff against default props), then the
 * font scale, max multiplier, and image request headers.
 */
template <typename PropsT>
static inline StyleConfig *ENRMStyleConfigFromProps(const PropsT &typedProps, CGFloat fontScale)
{
  StyleConfig *config = [[StyleConfig alloc] init];
  using StyleT = std::remove_cv_t<std::remove_reference_t<decltype(typedProps.markdownStyle)>>;
  static const StyleT kDefaultStyle{};
  applyMarkdownStyleToConfig(config, typedProps.markdownStyle, kDefaultStyle);
  [config setFontScaleMultiplier:fontScale];
  [config setMaxFontSizeMultiplier:typedProps.maxFontSizeMultiplier];
  [config setImageRequestHeaders:ENRMImageRequestHeadersFromProps(typedProps.imageRequestHeaders)];
  return config;
}

/**
 * Lays out an already-rendered attributed string in a fresh, call-confined
 * TextKit stack and finalizes with the shared algorithm
 * (`ENRMFinalizeMeasuredTextSize`). Returns CGSizeZero for empty text — the
 * same result the view path produces, and a guard against TextKit's
 * empty-string layout freeze (see RCTTextLayoutManager).
 *
 * `usesFontLeading` must be NO: a raw NSLayoutManager defaults to YES and
 * adds the used fonts' leading on top of the paragraph style's line-height
 * clamp, while the UITextView the visible view renders with does not. Fonts
 * pulled in by glyph fallback make this observable — Geeza Pro (Arabic)
 * carries nonzero leading, so with YES every Arabic-script line measures
 * taller than it renders and the surplus pools as phantom bottom space.
 * RCTTextLayoutManager disables it for the same view-parity reason.
 */
static inline CGSize ENRMMeasureAttributedTextViewFree(NSAttributedString *text, CGFloat maxWidth, StyleConfig *config,
                                                       BOOL allowTrailingMargin, CGFloat lastElementMarginBottom,
                                                       CGFloat pointScaleFactor)
{
  if (text.length == 0) {
    return CGSizeZero;
  }

  NSTextContainer *textContainer = [[NSTextContainer alloc] initWithSize:CGSizeMake(maxWidth, CGFLOAT_MAX)];
  textContainer.lineFragmentPadding = 0;
  NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
  layoutManager.allowsNonContiguousLayout = NO;
  layoutManager.usesFontLeading = NO;
  [layoutManager addTextContainer:textContainer];
  NSTextStorage *textStorage = [[NSTextStorage alloc] initWithAttributedString:text];
  [textStorage addLayoutManager:layoutManager];

  [layoutManager ensureLayoutForTextContainer:textContainer];
  ENRMTextLayoutResult layout;
  layout.usedRect = [layoutManager usedRectForTextContainer:textContainer];
  layout.extraLineFragmentRect = layoutManager.extraLineFragmentRect;

  return ENRMFinalizeMeasuredTextSize(layout, layoutManager, text, maxWidth, config, allowTrailingMargin,
                                      lastElementMarginBottom, pointScaleFactor);
}

/**
 * Measures EnrichedMarkdownText content from props alone, on the calling
 * thread. The line-break strategy and writing-direction mode are resolved
 * from the props exactly as `updateProps:` resolves them. Falls back to
 * (maxWidth × system-16 line height) for empty markdown, parse failures, and
 * empty render output — the same fallback `measureSize:` produced.
 */
template <typename PropsT>
static inline CGSize ENRMMeasureMarkdownViewFree(const PropsT &typedProps, CGFloat maxWidth, CGFloat fontScale,
                                                 CGFloat pointScaleFactor, NSWritingDirection resolvedLayoutDirection)
{
  @autoreleasepool {
    CGSize fallback = CGSizeMake(maxWidth, UIFontLineHeight([UIFont systemFontOfSize:16.0]));
    if (typedProps.markdown.empty()) {
      return fallback;
    }

    NSString *markdown = [[NSString alloc] initWithUTF8String:typedProps.markdown.c_str()];
    StyleConfig *config = ENRMStyleConfigFromProps(typedProps, fontScale);

    ENRMMd4cFlags *flags = ENRMMd4cFlagsFromProps(typedProps.md4cFlags);
    ENRMMarkdownParser *parser = [[ENRMMarkdownParser alloc] init];
    MarkdownASTNode *ast = [parser parseMarkdown:markdown flags:flags];
    if (!ast) {
      return fallback;
    }

    NSLineBreakStrategy lineBreakStrategy =
        ENRMResolveLineBreakStrategy([[NSString alloc] initWithUTF8String:typedProps.lineBreakStrategyIOS.c_str()]);
    ENRMRenderResult *result =
        ENRMRenderASTNodes(ast.children, config, typedProps.allowTrailingMargin, typedProps.allowFontScaling,
                           typedProps.maxFontSizeMultiplier, lineBreakStrategy);
    NSMutableAttributedString *text = result.attributedText;
    if (text.length == 0) {
      return fallback;
    }

    ENRMWritingDirectionMode writingDirectionMode =
        ENRMResolveWritingDirectionMode([[NSString alloc] initWithUTF8String:typedProps.writingDirection.c_str()]);
    ENRMApplyWritingDirectionMode(text, writingDirectionMode, resolvedLayoutDirection);

    CGSize size = ENRMMeasureAttributedTextViewFree(text, maxWidth, config, typedProps.allowTrailingMargin,
                                                    result.lastElementMarginBottom, pointScaleFactor);
    if (size.height == 0) {
      return fallback;
    }
    return size;
  }
}

/**
 * Measures segmented EnrichedMarkdown content from props alone, on the
 * calling thread, replicating the view path end to end: the streaming table
 * filter (`ENRMRenderableMarkdownForStreaming` with the props'
 * streamingConfig.tableMode), the segment split and per-segment rendering
 * (`ENRMRenderSegmentsFromAST` + per-text-segment writing direction — the
 * same calls `renderMarkdownContent:` makes), then the walk from
 * `computeSegmentLayoutForWidth:`: text segments include their trailing
 * margin unless last (`!isLast || allowTrailingMargin`), table and math
 * segments add their config marginTop before and marginBottom after under the
 * same condition, tables report full width. Finishes with `measureSize:`'s
 * pixel rounding (width capped at maxWidth) and its
 * (maxWidth × system-16 line height) fallback for empty/failed content.
 */
template <typename PropsT>
static inline CGSize ENRMMeasureSegmentedMarkdownViewFree(const PropsT &typedProps, CGFloat maxWidth, CGFloat fontScale,
                                                          CGFloat pointScaleFactor,
                                                          NSWritingDirection resolvedLayoutDirection)
{
  @autoreleasepool {
    CGSize fallback = CGSizeMake(maxWidth, UIFontLineHeight([UIFont systemFontOfSize:16.0]));
    if (typedProps.markdown.empty()) {
      return fallback;
    }

    NSString *markdown = [[NSString alloc] initWithUTF8String:typedProps.markdown.c_str()];

    if (typedProps.streamingAnimation) {
      NSString *tableModeStr = [[NSString alloc] initWithUTF8String:typedProps.streamingConfig.tableMode.c_str()];
      ENRMTableStreamingMode tableStreamingMode =
          [tableModeStr isEqualToString:@"hidden"] ? ENRMTableStreamingModeHidden : ENRMTableStreamingModeProgressive;
      NSString *codeBlockModeStr =
          [[NSString alloc] initWithUTF8String:typedProps.streamingConfig.codeBlockMode.c_str()];
      ENRMCodeBlockStreamingMode codeBlockStreamingMode = [codeBlockModeStr isEqualToString:@"hidden"]
                                                              ? ENRMCodeBlockStreamingModeHidden
                                                              : ENRMCodeBlockStreamingModeProgressive;
      markdown = ENRMRenderableMarkdownForStreaming(markdown, tableStreamingMode, codeBlockStreamingMode, NULL);
      if (markdown.length == 0) {
        return fallback;
      }
    }

    StyleConfig *config = ENRMStyleConfigFromProps(typedProps, fontScale);

    ENRMMd4cFlags *flags = ENRMMd4cFlagsFromProps(typedProps.md4cFlags);
    ENRMMarkdownParser *parser = [[ENRMMarkdownParser alloc] init];
    MarkdownASTNode *ast = [parser parseMarkdown:markdown flags:flags];
    if (!ast) {
      return fallback;
    }

    NSLineBreakStrategy lineBreakStrategy =
        ENRMResolveLineBreakStrategy([[NSString alloc] initWithUTF8String:typedProps.lineBreakStrategyIOS.c_str()]);
    ENRMWritingDirectionMode writingDirectionMode =
        ENRMResolveWritingDirectionMode([[NSString alloc] initWithUTF8String:typedProps.writingDirection.c_str()]);

    NSArray<ENRMRenderedSegment *> *segments =
        ENRMRenderSegmentsFromAST(ast, config, typedProps.allowTrailingMargin, typedProps.allowFontScaling,
                                  typedProps.maxFontSizeMultiplier, lineBreakStrategy);
    for (ENRMRenderedSegment *segment in segments) {
      if (segment.kind == ENRMSegmentKindText && segment.textResult) {
        ENRMApplyWritingDirectionMode(segment.textResult.attributedText, writingDirectionMode, resolvedLayoutDirection);
      }
    }

    if (segments.count == 0) {
      return fallback;
    }

    CGFloat yOffset = 0.0;
    CGFloat maxContentWidth = 0.0;
    const NSUInteger lastIndex = segments.count - 1;

    for (NSUInteger i = 0; i < segments.count; i++) {
      ENRMRenderedSegment *segment = segments[i];
      const BOOL isLast = (i == lastIndex);
      const BOOL shouldAddBottomMargin = (!isLast || typedProps.allowTrailingMargin);

      if (segment.kind == ENRMSegmentKindText && segment.textResult) {
        CGSize textSize = ENRMMeasureAttributedTextViewFree(
            segment.textResult.attributedText, maxWidth, config, shouldAddBottomMargin,
            segment.textResult.lastElementMarginBottom, pointScaleFactor);
        yOffset += textSize.height;
        maxContentWidth = MAX(maxContentWidth, textSize.width);
      } else if (segment.kind == ENRMSegmentKindTable && segment.tableSegment) {
        yOffset += config.tableMarginTop;
        yOffset += [TableContainerView measureHeightForTableNode:segment.tableSegment.tableNode
                                                          config:config
                                                allowFontScaling:typedProps.allowFontScaling
                                           maxFontSizeMultiplier:typedProps.maxFontSizeMultiplier
                                            writingDirectionMode:writingDirectionMode
                                         resolvedLayoutDirection:resolvedLayoutDirection];
        maxContentWidth = maxWidth;
        if (shouldAddBottomMargin) {
          yOffset += config.tableMarginBottom;
        }
      } else if (segment.kind == ENRMSegmentKindCodeBlock && segment.codeBlockSegment) {
        yOffset += config.codeBlockMarginTop;
        yOffset += [ENRMCodeBlockContainerView measureHeightForCodeBlockNode:segment.codeBlockSegment.codeBlockNode
                                                                      config:config];
        maxContentWidth = maxWidth;
        if (shouldAddBottomMargin) {
          yOffset += config.codeBlockMarginBottom;
        }
      }
#if ENRICHED_MARKDOWN_MATH
      else if (segment.kind == ENRMSegmentKindMath && segment.mathSegment) {
        yOffset += config.mathMarginTop;
        yOffset += [ENRMMathContainerView measureHeightForLatex:segment.mathSegment.latex
                                                         config:config
                                                       maxWidth:maxWidth];
        maxContentWidth = maxWidth;
        if (shouldAddBottomMargin) {
          yOffset += config.mathMarginBottom;
        }
      }
#endif
    }

    if (yOffset == 0) {
      return fallback;
    }

    CGFloat measuredWidth = MIN(ceil(maxContentWidth * pointScaleFactor) / pointScaleFactor, maxWidth);
    CGFloat measuredHeight = ceil(yOffset * pointScaleFactor) / pointScaleFactor;
    return CGSizeMake(measuredWidth, measuredHeight);
  }
}
