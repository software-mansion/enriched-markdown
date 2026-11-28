#import "SegmentRenderer.h"
#import "AccessibilityInfo.h"
#import "ENRMFeatureFlags.h"
#import "ENRMTextRenderCache.h"
#import "ENRMTextRenderer.h"
#import "ListItemRenderer.h"
#import "MarkdownASTNode.h"
#import "ParagraphStyleUtils.h"
#import "RenderContext.h"
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

// Mixes the first task index into the signature, so a segment re-renders when earlier tasks change.
static uint64_t ENRMMixTaskIndexOffset(uint64_t signature, NSInteger taskIndexOffset)
{
  uint64_t value = (uint64_t)taskIndexOffset;
  for (int byte = 0; byte < 8; byte++) {
    signature ^= (value >> (byte * 8)) & 0xFF;
    signature *= 1099511628211ULL;
  }
  return signature;
}

static uint64_t ENRMMixListContext(uint64_t signature, ENRMListSegment *context)
{
  if (!context)
    return signature;
  ENRMListMarkerDescriptor *marker = context.itemMarker;
  uint64_t width = 0;
  CGFloat parentWidth = context.parentMarkerWidth;
  memcpy(&width, &parentWidth, sizeof(parentWidth));
  uint64_t values[] = {(uint64_t)context.depth,
                       (uint64_t)context.taskIndexOffset,
                       width,
                       (uint64_t)context.withinBlockquote,
                       (uint64_t)(marker != nil),
                       (uint64_t)marker.listType,
                       (uint64_t)marker.number,
                       (uint64_t)marker.depth,
                       (uint64_t)marker.isTask,
                       (uint64_t)marker.isChecked,
                       (uint64_t)marker.taskIndex};
  for (NSUInteger i = 0; i < sizeof(values) / sizeof(values[0]); i++) {
    signature ^= values[i];
    signature *= 1099511628211ULL;
  }
  return signature;
}

static BOOL ENRMContainsTable(MarkdownASTNode *node)
{
  if (node.type == MarkdownNodeTypeTable)
    return YES;
  for (MarkdownASTNode *child in node.children) {
    if (ENRMContainsTable(child))
      return YES;
  }
  return NO;
}

NSInteger ENRMCountTaskItems(MarkdownASTNode *node)
{
  NSInteger count =
      node.type == MarkdownNodeTypeListItem && [node.attributes[@"isTask"] isEqualToString:@"true"] ? 1 : 0;
  for (MarkdownASTNode *child in node.children)
    count += ENRMCountTaskItems(child);
  return count;
}

static NSArray *ENRMSplitASTIntoSegments(MarkdownASTNode *root, BOOL nativeLists)
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
    } else if ((child.type == MarkdownNodeTypeOrderedList || child.type == MarkdownNodeTypeUnorderedList) &&
               (nativeLists || ENRMContainsTable(child))) {
      if (currentTextNodes.count > 0) {
        [segments addObject:[ENRMTextSegment segmentWithNodes:[currentTextNodes copy]]];
        [currentTextNodes removeAllObjects];
      }
      ENRMListSegment *list = [ENRMListSegment new];
      list.node = child;
      [segments addObject:list];
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

static uint64_t ENRMTextSignature(uint64_t nodesSignature, NSArray<MarkdownASTNode *> *nodes, StyleConfig *config,
                                  NSInteger taskIndexOffset, NSInteger taskItemCount)
{
  uint64_t signature = nodesSignature ^ kTextKindSalt;
  if (config.imageSourceOverrides.count > 0) {
    signature = ENRMMixImageSourceOverrides(signature, nodes, config.imageSourceOverrides);
  }
  if (taskItemCount > 0) {
    signature = ENRMMixTaskIndexOffset(signature, taskIndexOffset);
  }
  return signature;
}

// The text segment for `nodes`, through `cache` when there is one (ENRMTextRenderCache).
static ENRMRenderedSegment *ENRMRenderTextSegment(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config,
                                                  BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                  CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy,
                                                  BOOL blockquoteContent, ENRMWritingDirectionMode writingDirectionMode,
                                                  NSWritingDirection layoutDirection, BOOL isLast,
                                                  NSInteger taskIndexOffset, NSInteger taskItemCount,
                                                  ENRMTextRenderCache *cache)
{
  ENRMRenderResult * (^render)(void) = ^ENRMRenderResult * {
    return blockquoteContent ? ENRMRenderBlockquoteContentNodes(nodes, config, allowFontScaling, maxFontSizeMultiplier,
                                                                lineBreakStrategy, taskIndexOffset)
                             : ENRMRenderASTNodes(nodes, config, allowTrailingMargin, allowFontScaling,
                                                  maxFontSizeMultiplier, lineBreakStrategy, taskIndexOffset);
  };
  if (!cache) {
    return [ENRMRenderedSegment textSegmentWithResult:render()
                                            signature:ENRMTextSignature(ENRMSignatureForNodes(nodes), nodes, config,
                                                                        taskIndexOffset, taskItemCount)];
  }
  return [cache segmentForNodes:nodes
      isLast:isLast
      signature:^uint64_t(uint64_t nodesSignature) {
        return ENRMTextSignature(nodesSignature, nodes, config, taskIndexOffset, taskItemCount);
      }
      render:^ENRMRenderResult * {
        ENRMRenderResult *result = render();
        ENRMApplyWritingDirectionMode(result.attributedText, writingDirectionMode, layoutDirection);
        return result;
      }
      resume:^ENRMRenderResult *(NSUInteger from, ENRMRenderResult *previous) {
        // The previous render's task indices hold only if it started from the same one.
        if (previous.blockTaskStarts.firstObject.integerValue != taskIndexOffset) {
          return nil;
        }
        return ENRMRenderASTNodesResuming(nodes, from, previous, config, allowTrailingMargin, allowFontScaling,
                                          maxFontSizeMultiplier, lineBreakStrategy, writingDirectionMode,
                                          layoutDirection);
      }];
}

static NSArray<ENRMRenderedSegment *> *
ENRMRenderSegments(MarkdownASTNode *ast, StyleConfig *config, BOOL allowTrailingMargin, BOOL allowFontScaling,
                   CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy, BOOL blockquoteContent,
                   NSInteger startingTaskIndex, ENRMWritingDirectionMode writingDirectionMode,
                   NSWritingDirection layoutDirection, ENRMTextRenderCache *cache, ENRMListSegment *listContext)
{
  NSArray *segments = ENRMSplitASTIntoSegments(ast, listContext.depth > 0);
  NSUInteger lastTextIndex = [segments indexOfObjectWithOptions:NSEnumerationReverse
                                                    passingTest:^BOOL(id segment, NSUInteger index, BOOL *stop) {
                                                      return [segment isKindOfClass:[ENRMTextSegment class]];
                                                    }];
  NSMutableArray<ENRMRenderedSegment *> *renderedSegments = [NSMutableArray array];
  NSInteger taskIndexOffset = startingTaskIndex;

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
      if (listContext) {
        ENRMTextSegment *textSegment = (ENRMTextSegment *)segment;
        ENRMRenderResult *rendered = ENRMRenderASTNodesWithTaskOffset(
            textSegment.nodes, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier, lineBreakStrategy,
            blockquoteContent, taskIndexOffset);
        taskIndexOffset = rendered.context.taskItemCount;
        ENRMListMarkerDescriptor *marker = listContext.itemMarker;
        if (marker && rendered.attributedText.length > 0) {
          NSRange range = NSMakeRange(0, rendered.attributedText.length);
          NSMutableDictionary *attributes = [@{
            ListDepthAttribute : @(marker.depth),
            ListTypeAttribute : @(marker.listType),
            ListItemNumberAttribute : @(marker.number)
          } mutableCopy];
          if (marker.isTask) {
            attributes[TaskItemAttribute] = @YES;
            attributes[TaskCheckedAttribute] = @(marker.isChecked);
            attributes[TaskIndexAttribute] = @(marker.taskIndex);
            if (marker.isChecked) {
              if (config.taskListCheckedStrikethrough)
                attributes[NSStrikethroughStyleAttributeName] = @(NSUnderlineStyleSingle);
              if (config.taskListCheckedTextColor)
                attributes[NSForegroundColorAttributeName] = config.taskListCheckedTextColor;
            }
          }
          [rendered.attributedText addAttributes:attributes range:range];
          [rendered.context registerListItemRange:range
                                         position:marker.number
                                            depth:marker.depth + 1
                                        isOrdered:marker.listType == ListTypeOrdered];
          rendered.accessibilityInfo = [AccessibilityInfo infoFromContext:rendered.context];
        }
        uint64_t signature = ENRMSignatureForNodes(textSegment.nodes) ^ kTextKindSalt;
        signature = ENRMMixListContext(signature, listContext);
        signature ^= (uint64_t)rendered.context.taskItemCount;
        if (imageSourceOverrides.count > 0) {
          signature = ENRMMixImageSourceOverrides(signature, textSegment.nodes, imageSourceOverrides);
        }
        [renderedSegments addObject:[ENRMRenderedSegment textSegmentWithResult:rendered signature:signature]];
      } else {
        NSArray<MarkdownASTNode *> *nodes = ((ENRMTextSegment *)segment).nodes;
        NSInteger taskItemCount = 0;
        for (MarkdownASTNode *node in nodes) {
          taskItemCount += ENRMCountTaskItems(node);
        }
        [renderedSegments
            addObject:ENRMRenderTextSegment(nodes, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                                            lineBreakStrategy, blockquoteContent, writingDirectionMode, layoutDirection,
                                            segmentIndex == lastTextIndex, taskIndexOffset, taskItemCount, cache)];
        taskIndexOffset += taskItemCount;
      }
    } else if ([segment isKindOfClass:[ENRMListSegment class]]) {
      ENRMListSegment *list = (ENRMListSegment *)segment;
      list.writingDirectionMode = writingDirectionMode;
      list.resolvedLayoutDirection = layoutDirection;
      list.depth = listContext.depth;
      list.parentMarkerWidth = listContext.parentMarkerWidth;
      list.withinBlockquote = blockquoteContent || listContext.withinBlockquote;
      list.taskIndexOffset = taskIndexOffset;
      taskIndexOffset += ENRMCountTaskItems(list.node);
      uint64_t signature = ENRMSignatureForNode(list.node) ^ 0x6c69737400000000ULL ^ ((uint64_t)list.depth << 32) ^
                           (uint64_t)list.taskIndexOffset;
      signature = ENRMMixListContext(signature, list);
      if (imageSourceOverrides.count > 0)
        signature = ENRMMixImageSourceOverrides(signature, @[ list.node ], imageSourceOverrides);
      [renderedSegments addObject:[ENRMRenderedSegment listSegmentWithSegment:list signature:signature]];
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
      ENRMListSegment *quoteContext = listContext ? [listContext copy] : [ENRMListSegment new];
      quoteContext.writingDirectionMode = writingDirectionMode;
      quoteContext.resolvedLayoutDirection = layoutDirection;
      quoteContext.taskIndexOffset = taskIndexOffset;
      quoteContext.withinBlockquote = YES;
      blockquoteSegment.listContext = quoteContext;
      uint64_t signature = ENRMMixListContext(
          ENRMSignatureForNode(blockquoteSegment.blockquoteNode) ^ kBlockquoteKindSalt, quoteContext);
      if (imageSourceOverrides.count > 0) {
        signature = ENRMMixImageSourceOverrides(signature, @[ blockquoteSegment.blockquoteNode ], imageSourceOverrides);
      }
      NSInteger taskItemCount = ENRMCountTaskItems(blockquoteSegment.blockquoteNode);
      if (taskItemCount > 0) {
        signature = ENRMMixTaskIndexOffset(signature, taskIndexOffset);
      }
      blockquoteSegment.taskIndexOffset = taskIndexOffset;
      taskIndexOffset += taskItemCount;
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

  if (listContext)
    ENRMApplySegmentWritingDirection(renderedSegments, listContext.writingDirectionMode,
                                     listContext.resolvedLayoutDirection);
  return renderedSegments;
}

NSArray<ENRMRenderedSegment *> *ENRMRenderSegmentsFromAST(MarkdownASTNode *ast, StyleConfig *config,
                                                          BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                          CGFloat maxFontSizeMultiplier,
                                                          NSLineBreakStrategy lineBreakStrategy, BOOL blockquoteContent,
                                                          NSInteger startingTaskIndex)
{
  return ENRMRenderSegments(ast, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                            lineBreakStrategy, blockquoteContent, startingTaskIndex,
                            ENRMWritingDirectionModeFirstStrong, NSWritingDirectionNatural, /*cache*/ nil,
                            /*listContext*/ nil);
}

NSArray<ENRMRenderedSegment *> *
ENRMRenderSegmentsFromASTCached(MarkdownASTNode *ast, StyleConfig *config, BOOL allowTrailingMargin,
                                BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                NSLineBreakStrategy lineBreakStrategy, ENRMWritingDirectionMode writingDirectionMode,
                                NSWritingDirection layoutDirection, ENRMTextRenderCache *cache)
{
  return ENRMRenderSegments(ast, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                            lineBreakStrategy, /*blockquoteContent*/ NO, /*startingTaskIndex*/ 0, writingDirectionMode,
                            layoutDirection, cache, /*listContext*/ nil);
}

ENRMRenderResult *ENRMRenderTextCached(NSArray<MarkdownASTNode *> *nodes, StyleConfig *config, BOOL allowTrailingMargin,
                                       BOOL allowFontScaling, CGFloat maxFontSizeMultiplier,
                                       NSLineBreakStrategy lineBreakStrategy,
                                       ENRMWritingDirectionMode writingDirectionMode,
                                       NSWritingDirection layoutDirection, ENRMTextRenderCache *cache)
{
  return ENRMRenderTextSegment(nodes, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                               lineBreakStrategy, /*blockquoteContent*/ NO, writingDirectionMode, layoutDirection,
                               /*isLast*/ YES, /*taskIndexOffset*/ 0, /*taskItemCount*/ 0, cache)
      .textResult;
}

void ENRMApplySegmentWritingDirection(NSArray<ENRMRenderedSegment *> *segments, ENRMWritingDirectionMode mode,
                                      NSWritingDirection layoutDirection)
{
  for (ENRMRenderedSegment *segment in segments) {
    if (segment.kind == ENRMSegmentKindText) {
      ENRMApplyWritingDirectionMode(segment.textResult.attributedText, mode, layoutDirection);
    } else {
      ENRMListSegment *context =
          segment.kind == ENRMSegmentKindList ? segment.listSegment : segment.blockquoteSegment.listContext;
      context.writingDirectionMode = mode;
      context.resolvedLayoutDirection = layoutDirection;
    }
  }
}

NSArray<ENRMRenderedSegment *> *ENRMRenderListItemSegments(MarkdownASTNode *item, StyleConfig *config,
                                                           ENRMListSegment *parent, ENRMListMarkerDescriptor *marker,
                                                           BOOL allowFontScaling, NSLineBreakStrategy lineBreakStrategy)
{
  ENRMListSegment *context = [parent copy];
  context.depth = parent.depth + 1;
  context.itemMarker = marker;
  context.taskIndexOffset = marker.taskIndex + (marker.isTask ? 1 : 0);
  context.parentMarkerWidth = marker.isTask
                                  ? config.effectiveListMarginLeftForTask
                                  : (marker.listType == ListTypeOrdered ? [config effectiveListMarginLeftForNumber:99]
                                                                        : config.effectiveListMarginLeftForBullet);
  return ENRMRenderSegmentsWithListContext(item, [config configForListItemBody], NO, allowFontScaling,
                                           config.maxFontSizeMultiplier, lineBreakStrategy, NO, context);
}

NSArray<ENRMRenderedSegment *> *ENRMRenderSegmentsWithListContext(MarkdownASTNode *ast, StyleConfig *config,
                                                                  BOOL allowTrailingMargin, BOOL allowFontScaling,
                                                                  CGFloat maxFontSizeMultiplier,
                                                                  NSLineBreakStrategy lineBreakStrategy,
                                                                  BOOL blockquoteContent, ENRMListSegment *listContext)
{
  return ENRMRenderSegments(
      ast, config, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier, lineBreakStrategy, blockquoteContent,
      listContext.taskIndexOffset, listContext ? listContext.writingDirectionMode : ENRMWritingDirectionModeFirstStrong,
      listContext ? listContext.resolvedLayoutDirection : NSWritingDirectionNatural, nil, listContext);
}
