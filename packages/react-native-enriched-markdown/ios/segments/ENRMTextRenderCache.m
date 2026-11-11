#import "ENRMTextRenderCache.h"
#import "ENRMTextRenderer.h"
#import "MarkdownASTNode.h"
#import "RenderedMarkdownSegment.h"
#import "StyleConfig.h"
#import <stdatomic.h>

static _Atomic uint64_t gNextRevision = 0;

NSArray *ENRMTextRenderKey(StyleConfig *config, size_t styleFingerprint, BOOL allowFontScaling,
                           CGFloat maxFontSizeMultiplier, NSLineBreakStrategy lineBreakStrategy,
                           ENRMWritingDirectionMode writingDirectionMode, NSWritingDirection layoutDirection,
                           NSUInteger epoch)
{
  return @[
    @(styleFingerprint), @(config.fontScaleMultiplier), @(allowFontScaling), @(maxFontSizeMultiplier),
    @(lineBreakStrategy), @(writingDirectionMode), @(layoutDirection), config.imageRequestHeaders ?: [NSNull null],
    config.imageSourceOverrides ?: [NSNull null], config.linkPillContent ?: [NSNull null], @(epoch)
  ];
}

// What the cache keeps of a segment it hands out: views hold the text, and resuming needs only the
// rest. A view that needs the text of a segment handed out again gets a full render.
static ENRMRenderedSegment *ENRMKeptSegment(ENRMRenderedSegment *segment)
{
  ENRMRenderResult *result = segment.textResult;
  ENRMRenderResult *kept = [[ENRMRenderResult alloc] init];
  kept.textLength = result.textLength;
  kept.context = result.context;
  kept.accessibilityInfo = result.accessibilityInfo;
  kept.lastElementMarginBottom = result.lastElementMarginBottom;
  kept.blockStarts = result.blockStarts;
  kept.blockTaskStarts = result.blockTaskStarts;
  kept.blockMathStarts = result.blockMathStarts;
  kept.blockSeeds = result.blockSeeds;
  kept.revision = result.revision;
  return [ENRMRenderedSegment textSegmentWithResult:kept signature:segment.signature];
}

@implementation ENRMTextRenderCache {
  NSArray *_key;
  NSArray<ENRMRenderedSegment *> *_previous;
  NSMutableArray<ENRMRenderedSegment *> *_available;
  NSMutableArray<ENRMRenderedSegment *> *_current;
  ENRMRenderedSegment *_growing;
  NSArray<NSNumber *> *_growingNodeSignatures;
}

- (instancetype)init
{
  if (self = [super init]) {
    _previous = @[];
    _current = [NSMutableArray array];
  }
  return self;
}

- (void)clear
{
  _key = nil;
  _previous = @[];
  _growing = nil;
  _growingNodeSignatures = nil;
}

- (void)beginRenderWithKey:(NSArray *)key
{
  if (![key isEqualToArray:_key]) {
    [self clear];
  }
  _key = [key copy];
  [_current removeAllObjects];
  _available = [_previous mutableCopy];
}

- (void)endRender
{
  _previous = [_current copy];
  _available = nil;
}

- (ENRMRenderedSegment *)segmentForNodes:(NSArray<MarkdownASTNode *> *)nodes
                                  isLast:(BOOL)isLast
                               signature:(uint64_t (^)(uint64_t))signatureOfNodes
                                  render:(ENRMRenderResult * (^)(void))render
                                  resume:(ENRMRenderResult * (^)(NSUInteger, ENRMRenderResult *))resume
{
  NSMutableArray<NSNumber *> *nodeSignatures = [NSMutableArray arrayWithCapacity:nodes.count];
  for (MarkdownASTNode *node in nodes) {
    [nodeSignatures addObject:@(ENRMSignatureForNode(node))];
  }
  const uint64_t signature = signatureOfNodes(ENRMSignatureForNodeSignatures(nodeSignatures));

  for (NSUInteger i = 0; i < _available.count; i++) {
    ENRMRenderedSegment *segment = _available[i];
    if (segment.signature == signature) {
      [_available removeObjectAtIndex:i];
      [_current addObject:segment];
      return segment;
    }
  }

  ENRMRenderResult *result = isLast ? [self resultResumingNodes:nodeSignatures resume:resume] : nil;
  if (!result) {
    result = render();
    if (isLast) {
      result.blockSeeds = ENRMBlockSeeds(result.attributedText, result.blockStarts);
    }
  }
  result.revision = atomic_fetch_add(&gNextRevision, 1) + 1;
  ENRMRenderedSegment *segment = [ENRMRenderedSegment textSegmentWithResult:result signature:signature];
  ENRMRenderedSegment *kept = ENRMKeptSegment(segment);
  [_current addObject:kept];
  if (isLast) {
    _growing = kept;
    _growingNodeSignatures = nodeSignatures;
  }
  return segment;
}

- (ENRMRenderResult *)resultResumingNodes:(NSArray<NSNumber *> *)nodeSignatures
                                   resume:(ENRMRenderResult * (^)(NSUInteger, ENRMRenderResult *))resume
{
  ENRMRenderResult *previous = _growing.textResult;
  NSArray<NSNumber *> *old = _growingNodeSignatures;
  if (!previous || old.count == 0 || nodeSignatures.count == 0) {
    return nil;
  }
  NSUInteger common = 0;
  while (common < nodeSignatures.count && common < old.count && [nodeSignatures[common] isEqual:old[common]]) {
    common++;
  }
  // No later than the last node of either render (see the header).
  const NSUInteger from = MIN(common, MIN(old.count, nodeSignatures.count) - 1);
  return from > 0 ? resume(from, previous) : nil;
}

@end
