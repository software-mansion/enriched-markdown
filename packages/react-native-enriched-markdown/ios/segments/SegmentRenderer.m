#import "SegmentRenderer.h"
#import "ENRMFeatureFlags.h"
#import "ENRMTextRenderCache.h"
#import "ENRMTextRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderedMarkdownSegment.h"
#import "StyleConfig.h"

static inline uint64_t ENRMMixString(uint64_t hash, NSString *string)
{
  const char *utf8 = [string UTF8String];
  while (utf8 && *utf8) {
    hash ^= (uint8_t)*utf8++;
    hash *= 1099511628211ULL;
  }
  return hash;
}

// The source an image loads comes from the `imageSources` prop, not the AST, so
// it joins the signature: the reconciler keeps a view whose signature matches
// as it is, and that view must not hold the previous source's attachment.
static uint64_t ENRMMixImageSourceOverrides(uint64_t hash, NSArray<MarkdownASTNode *> *nodes,
                                            NSDictionary<NSString *, ENRMImageSourceOverride *> *overrides)
{
  for (MarkdownASTNode *node in nodes) {
    NSString *occurrenceId = node.attributes[@"imageOccurrenceId"];
    ENRMImageSourceOverride *override = occurrenceId ? overrides[occurrenceId] : nil;
    if (override) {
      hash = ENRMMixString(hash, override.uri);
      for (NSString *key in [override.headers.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        hash = ENRMMixString(hash, key);
        hash = ENRMMixString(hash, override.headers[key]);
      }
    }
    hash = ENRMMixImageSourceOverrides(hash, node.children, overrides);
  }
  return hash;
}

static NSArray *ENRMSplitASTIntoSegments(MarkdownASTNode *root)
{
  NSMutableArray *segments = [NSMutableArray array];
  NSMutableArray *currentTextNodes = [NSMutableArray array];

  for (MarkdownASTNode *child in root.children) {
    NSString *blockSlotId = child.attributes[@"blockSlotId"];
    if (blockSlotId.length > 0) {
      // A React child replaces this block (BlockSlots.hpp stamps only the ids the
      // host asked for); the host reserves the slot and Fabric mounts the child.
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      NSString *kindName = child.attributes[@"blockSlotKind"];
      ENRMBlockSlotKind kind = [kindName isEqualToString:@"video"]  ? ENRMBlockSlotKindVideo
                               : [kindName isEqualToString:@"link"] ? ENRMBlockSlotKindLink
                               : [kindName isEqualToString:@"code"] ? ENRMBlockSlotKindCode
                                                                    : ENRMBlockSlotKindImage;
      [segments addObject:[ENRMBlockSlotSegment segmentWithSlotId:blockSlotId kind:kind]];
    } else if (child.type == MarkdownNodeTypeTable) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      [segments addObject:[ENRMTableSegment segmentWithTableNode:child]];
    }
#if ENRICHED_MARKDOWN_MATH
    else if (child.type == MarkdownNodeTypeLatexMathDisplay) {
#if !TARGET_OS_OSX
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      NSString *latex = child.children.count > 0 ? child.children.firstObject.content : child.content;
      [segments addObject:[ENRMMathSegment segmentWithLatex:latex ?: @""]];
#else
      // TODO: Fix block math rendering on macOS. Adding ENRMMathContainerView as a
      // segment causes all preceding text segments to become invisible.
#endif
    }
#endif
    else if (child.type == MarkdownNodeTypeCodeBlock) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      [segments addObject:[ENRMCodeBlockSegment segmentWithCodeBlockNode:child]];
    } else if (child.type == MarkdownNodeTypeBlockquote || child.type == MarkdownNodeTypeAdmonition) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      [segments addObject:[ENRMBlockquoteSegment segmentWithBlockquoteNode:child]];
    }
#if ENRICHED_MARKDOWN_VIDEO
    else if (child.type == MarkdownNodeTypeVideo) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      [segments addObject:[ENRMVideoSegment segmentWithVideoNode:child]];
    }
#endif
    else {
      [currentTextNodes addObject:child];
    }
  }

  if (currentTextNodes.count > 0) {
    [segments addObject:[ENRMTextSegment segmentWithNodes:currentTextNodes]];
  }

  return segments;
}

static const uint64_t kTextKindSalt = 0x7465787400000000ULL; // "text"

static uint64_t ENRMTextSignature(uint64_t nodesSignature, NSArray<MarkdownASTNode *> *nodes, StyleConfig *config)
{
  uint64_t signature = nodesSignature ^ kTextKindSalt;
  if (config.imageSourceOverrides.count > 0) {
    signature = ENRMMixImageSourceOverrides(signature, nodes, config.imageSourceOverrides);
  }
  return signature;
}

// The text segment for `nodes`, through `cache` when there is one (ENRMTextRenderCache).
static ENRMRenderedSegment *ENRMRenderTextSegment(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config,
                                                  BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                  CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy,
                                                  BOOL blockquoteContent, ENRMWritingDirectionMode writingDirectionMode,
                                                  NSWritingDirection layoutDirection, BOOL isLast,
                                                  ENRMTextRenderCache *cache)
{
  ENRMRenderResult * (^render)(void) = ^ENRMRenderResult * {
    return blockquoteContent ? ENRMRenderBlockquoteContentNodes(nodes, config, allowFontScaling, maxFontSizeMultiplier,
                                                                lineBreakStrategy)
                             : ENRMRenderASTNodes(nodes, config, allowTrailingMargin, allowFontScaling,
                                                  maxFontSizeMultiplier, lineBreakStrategy);
  };
  if (!cache) {
    return [ENRMRenderedSegment textSegmentWithResult:render()
                                            signature:ENRMTextSignature(ENRMSignatureForNodes(nodes), nodes, config)];
  }
  return [cache segmentForNodes:nodes
      isLast:isLast
      signature:^uint64_t(uint64_t nodesSignature) { return ENRMTextSignature(nodesSignature, nodes, config); }
      render:^ENRMRenderResult * {
        ENRMRenderResult *result = render();
        ENRMApplyWritingDirectionMode(result.attributedText, writingDirectionMode, layoutDirection);
        return result;
      }
      resume:^ENRMRenderResult *(NSUInteger from, ENRMRenderResult *previous) {
        return ENRMRenderASTNodesResuming(nodes, from, previous, config, allowTrailingMargin, allowFontScaling,
                                          maxFontSizeMultiplier, lineBreakStrategy, writingDirectionMode,
                                          layoutDirection);
      }];
}

static NSArray<ENRMRenderedSegment *> *
ENRMRenderSegments(MarkdownASTNode *ast, StyleConfig *config, BOOL allowTrailingMargin, BOOL allowFontScaling,
                   CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy, BOOL blockquoteContent,
                   ENRMWritingDirectionMode writingDirectionMode, NSWritingDirection layoutDirection,
                   ENRMTextRenderCache *cache)
{
  NSArray *segments = ENRMSplitASTIntoSegments(ast);
  NSUInteger lastTextIndex = [segments indexOfObjectWithOptions:NSEnumerationReverse
                                                    passingTest:^BOOL(id segment, NSUInteger index, BOOL *stop) {
                                                      return [segment isKindOfClass:[ENRMTextSegment class]];
                                                    }];
  NSMutableArray<ENRMRenderedSegment *> *renderedSegments = [NSMutableArray array];

  static const uint64_t kTableKindSalt = 0x7461626C00000000ULL;      // "tabl"
  static const uint64_t kMathKindSalt = 0x6D61746800000000ULL;       // "math"
  static const uint64_t kCodeBlockKindSalt = 0x63626C6B00000000ULL;  // "cblk"
  static const uint64_t kBlockquoteKindSalt = 0x6271746500000000ULL; // "bqte"
  static const uint64_t kVideoKindSalt = 0x7669646F00000000ULL;      // "vido"
  static const uint64_t kBlockSlotKindSalt = 0x626C736C00000000ULL;  // "blsl"
  NSDictionary<NSString *, ENRMImageSourceOverride *> *imageSourceOverrides = config.imageSourceOverrides;

  for (NSUInteger segmentIndex = 0; segmentIndex < segments.count; segmentIndex++) {
    id segment = segments[segmentIndex];
    if ([segment isKindOfClass:[ENRMTextSegment class]]) {
      [renderedSegments
          addObject:ENRMRenderTextSegment(((ENRMTextSegment *)segment).nodes, config, allowTrailingMargin,
                                          allowFontScaling, maxFontSizeMultiplier, lineBreakStrategy, blockquoteContent,
                                          writingDirectionMode, layoutDirection, segmentIndex == lastTextIndex, cache)];
    } else if ([segment isKindOfClass:[ENRMTableSegment class]]) {
      ENRMTableSegment *tableSegment = (ENRMTableSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(tableSegment.tableNode) ^ kTableKindSalt;
      if (imageSourceOverrides.count > 0) {
        signature = ENRMMixImageSourceOverrides(signature, @[ tableSegment.tableNode ], imageSourceOverrides);
      }
      [renderedSegments addObject:[ENRMRenderedSegment tableSegmentWithSegment:tableSegment signature:signature]];
    }
#if ENRICHED_MARKDOWN_MATH
    else if ([segment isKindOfClass:[ENRMMathSegment class]]) {
      ENRMMathSegment *mathSegment = (ENRMMathSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(nil) ^ kMathKindSalt;
      NSString *latex = mathSegment.latex ?: @"";
      const char *utf8 = [latex UTF8String];
      while (*utf8) {
        signature ^= (uint8_t)*utf8++;
        signature *= 1099511628211ULL;
      }
      [renderedSegments addObject:[ENRMRenderedSegment mathSegmentWithSegment:mathSegment signature:signature]];
    }
#endif
    else if ([segment isKindOfClass:[ENRMCodeBlockSegment class]]) {
      ENRMCodeBlockSegment *codeBlockSegment = (ENRMCodeBlockSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(codeBlockSegment.codeBlockNode) ^ kCodeBlockKindSalt;
      [renderedSegments addObject:[ENRMRenderedSegment codeBlockSegmentWithSegment:codeBlockSegment
                                                                         signature:signature]];
    } else if ([segment isKindOfClass:[ENRMBlockquoteSegment class]]) {
      ENRMBlockquoteSegment *blockquoteSegment = (ENRMBlockquoteSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(blockquoteSegment.blockquoteNode) ^ kBlockquoteKindSalt;
      if (imageSourceOverrides.count > 0) {
        signature = ENRMMixImageSourceOverrides(signature, @[ blockquoteSegment.blockquoteNode ], imageSourceOverrides);
      }
      [renderedSegments addObject:[ENRMRenderedSegment blockquoteSegmentWithSegment:blockquoteSegment
                                                                          signature:signature]];
    }
#if ENRICHED_MARKDOWN_VIDEO
    else if ([segment isKindOfClass:[ENRMVideoSegment class]]) {
      ENRMVideoSegment *videoSegment = (ENRMVideoSegment *)segment;
      uint64_t signature = ENRMSignatureForNode(videoSegment.videoNode) ^ kVideoKindSalt;
      [renderedSegments addObject:[ENRMRenderedSegment videoSegmentWithSegment:videoSegment signature:signature]];
    }
#endif
    else if ([segment isKindOfClass:[ENRMBlockSlotSegment class]]) {
      ENRMBlockSlotSegment *blockSlotSegment = (ENRMBlockSlotSegment *)segment;
      uint64_t signature = kBlockSlotKindSalt;
      const char *utf8 = [blockSlotSegment.slotId UTF8String];
      while (utf8 && *utf8) {
        signature ^= (uint8_t)*utf8++;
        signature *= 1099511628211ULL;
      }
      [renderedSegments addObject:[ENRMRenderedSegment blockSlotSegmentWithSegment:blockSlotSegment
                                                                         signature:signature]];
    }
  }

  return renderedSegments;
}

NSArray<ENRMRenderedSegment *> *ENRMRenderSegmentsFromAST(MarkdownASTNode *ast, StyleConfig *config,
                                                          BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                          CGFloat maxFontSizeMultiplier,
                                                          NSLineBreakStrategy lineBreakStrategy, BOOL blockquoteContent)
{
  return ENRMRenderSegments(ast, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                            lineBreakStrategy, blockquoteContent, ENRMWritingDirectionModeFirstStrong,
                            NSWritingDirectionNatural, /*cache*/ nil);
}

NSArray<ENRMRenderedSegment *> *
ENRMRenderSegmentsFromASTCached(MarkdownASTNode *ast, StyleConfig *config, BOOL allowTrailingMargin,
                                BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                NSLineBreakStrategy lineBreakStrategy, ENRMWritingDirectionMode writingDirectionMode,
                                NSWritingDirection layoutDirection, ENRMTextRenderCache *cache)
{
  return ENRMRenderSegments(ast, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                            lineBreakStrategy, /*blockquoteContent*/ NO, writingDirectionMode, layoutDirection, cache);
}

ENRMRenderResult *ENRMRenderTextCached(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                       BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                       NSLineBreakStrategy lineBreakStrategy,
                                       ENRMWritingDirectionMode writingDirectionMode,
                                       NSWritingDirection layoutDirection, ENRMTextRenderCache *cache)
{
  return ENRMRenderTextSegment(nodes, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                               lineBreakStrategy, /*blockquoteContent*/ NO, writingDirectionMode, layoutDirection,
                               /*isLast*/ YES, cache)
      .textResult;
}
