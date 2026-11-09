#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/ENRMTextRenderCache.h"
#import "../../ios/segments/RenderedMarkdownSegment.h"
#import "../../ios/segments/SegmentRenderer.h"
#import "../../ios/styles/StyleConfig.h"
#import "../../ios/utils/AccessibilityInfo.h"
#import "../../ios/utils/ENRMTextRenderer.h"
#import "../../ios/utils/ParagraphStyleUtils.h"
#import "../../ios/views/EnrichedMarkdownInternalText.h"
#import <XCTest/XCTest.h>

static NSString *const kDocument =
    @"# Setting up\n\n"
    @"To get started, install **the tools** and read the [guide](https://e.com).\n\n"
    @"- Clone the *repo*\n- Install `deps`\n  - nested item\n\n"
    @"3. One\n4. Two, with **bold**\n\n"
    @"- [x] Done\n- [ ] Next\n\n"
    @"> A quote in between\n\n"
    @"## Key steps\n\n"
    @"مرحبا بالعالم، this paragraph starts right to left.\n\n"
    @"```\ncode block\n```\n\n"
    @"- [ ] After the code\n\n"
    @"That's it, you now have an _almost_ **working setup**.\n";

@interface ENRMTextRenderCacheTests : XCTestCase
@end

@implementation ENRMTextRenderCacheTests {
  ENRMMarkdownParser *_parser;
  StyleConfig *_config;
}

- (void)setUp
{
  _parser = [[ENRMMarkdownParser alloc] init];
  _config = [[StyleConfig alloc] init];
}

- (NSArray<ENRMRenderedSegment *> *)render:(NSString *)markdown cache:(ENRMTextRenderCache *)cache
{
  MarkdownASTNode *ast = [_parser parseMarkdown:markdown flags:[ENRMMd4cFlags defaultFlags] isGFM:YES];
  if (!cache) {
    NSArray<ENRMRenderedSegment *> *segments =
        ENRMRenderSegmentsFromAST(ast, _config, NO, YES, 0, NSLineBreakStrategyStandard, NO);
    for (ENRMRenderedSegment *segment in segments) {
      if (segment.kind == ENRMSegmentKindText) {
        ENRMApplyWritingDirectionMode(segment.textResult.attributedText, ENRMWritingDirectionModeFirstStrong,
                                      NSWritingDirectionLeftToRight);
      }
    }
    return segments;
  }
  [cache beginRenderWithKey:@[ @1 ]];
  NSArray<ENRMRenderedSegment *> *segments =
      ENRMRenderSegmentsFromASTCached(ast, _config, NO, YES, 0, NSLineBreakStrategyStandard,
                                      ENRMWritingDirectionModeFirstStrong, NSWritingDirectionLeftToRight, cache);
  [cache endRender];
  return segments;
}

// Attribute values compared by what they hold: each render makes its own list markers.
static id ENRMComparable(id value)
{
  if ([value isKindOfClass:[NSArray class]]) {
    NSMutableArray *items = [NSMutableArray array];
    for (id item in value) {
      [items addObject:ENRMComparable(item)];
    }
    return items;
  }
  // By name: the test bundle and the app each have a copy of the class.
  if ([NSStringFromClass([value class]) isEqualToString:@"ENRMListMarkerDescriptor"]) {
    return [value dictionaryWithValuesForKeys:@[
      @"isTask", @"isChecked", @"taskIndex", @"listType", @"number", @"depth", @"indent"
    ]];
  }
  return value;
}

// Nil when `a` and `b` hold the same text and attributes, else where they first differ.
static NSString *_Nullable ENRMDifference(NSAttributedString *a, NSAttributedString *b)
{
  if (![a.string isEqualToString:b.string]) {
    return [NSString stringWithFormat:@"text %@ vs %@", [a.string debugDescription], [b.string debugDescription]];
  }
  for (NSUInteger i = 0; i < a.length; i++) {
    NSDictionary *x = [a attributesAtIndex:i effectiveRange:NULL];
    NSDictionary *y = [b attributesAtIndex:i effectiveRange:NULL];
    for (id key in [NSSet setWithArray:[x.allKeys arrayByAddingObjectsFromArray:y.allKeys]]) {
      if (![ENRMComparable(x[key]) isEqual:ENRMComparable(y[key])]) {
        return [NSString stringWithFormat:@"%@ at %lu of %lu: %@ vs %@", key, i, a.length, ENRMComparable(x[key]),
                                          ENRMComparable(y[key])];
      }
    }
  }
  return nil;
}

static NSArray<ENRMRenderedSegment *> *ENRMTextSegmentsOf(NSArray<ENRMRenderedSegment *> *segments)
{
  return [segments filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(ENRMRenderedSegment *segment,
                                                                                     NSDictionary *bindings) {
                     return segment.kind == ENRMSegmentKindText;
                   }]];
}

- (void)testEveryPrefixRendersAsAFullRenderAndPatchesTheShownText
{
  ENRMTextRenderCache *cache = [[ENRMTextRenderCache alloc] init];
  // What a view for each text segment shows, by position: its text storage fixes paragraph
  // attributes, so it is compared to a storage holding the full render.
  NSMutableArray<NSTextStorage *> *shown = [NSMutableArray array];
  NSMutableArray<NSNumber *> *shownRevisions = [NSMutableArray array];
  NSUInteger patches = 0;
  NSUInteger states = 0;

  for (NSUInteger length = 1; length <= kDocument.length; length += 3) {
    NSString *markdown = [kDocument substringToIndex:length];
    NSArray<ENRMRenderedSegment *> *cached = ENRMTextSegmentsOf([self render:markdown cache:cache]);
    NSArray<ENRMRenderedSegment *> *full = ENRMTextSegmentsOf([self render:markdown cache:nil]);
    XCTAssertEqual(cached.count, full.count, @"%@", markdown);
    states++;

    for (NSUInteger i = 0; i < MIN(cached.count, full.count); i++) {
      ENRMRenderResult *result = cached[i].textResult;
      NSAttributedString *expected = full[i].textResult.attributedText;
      XCTAssertEqual(cached[i].signature, full[i].signature);
      // A full render, a patch, or the segment handed back as it was (no text: the view shows it).
      if (result.attributedText) {
        XCTAssertNil(ENRMDifference(result.attributedText, expected), @"segment %lu of %@", i, markdown);
      }
      XCTAssertEqual(result.textLength, expected.length);
      XCTAssertEqualWithAccuracy(result.lastElementMarginBottom, full[i].textResult.lastElementMarginBottom, 0.001);
      AccessibilityInfo *info = result.accessibilityInfo, *expectedInfo = full[i].textResult.accessibilityInfo;
      XCTAssertEqualObjects(info.headingRanges, expectedInfo.headingRanges);
      XCTAssertEqualObjects(info.linkRanges, expectedInfo.linkRanges);
      XCTAssertEqualObjects(info.listItemRanges, expectedInfo.listItemRanges);
      XCTAssertEqualObjects(info.listItemPositions, expectedInfo.listItemPositions);

      if (i >= shown.count) {
        [shown addObject:[[NSTextStorage alloc] init]];
        [shownRevisions addObject:@0];
      }
      NSTextStorage *storage = shown[i];
      if (result.patchTail && result.patchBaseRevision == shownRevisions[i].unsignedLongLongValue) {
        [storage replaceCharactersInRange:NSMakeRange(result.patchStart, storage.length - result.patchStart)
                     withAttributedString:result.patchTail];
        patches++;
      } else if (result.revision != shownRevisions[i].unsignedLongLongValue) {
        XCTAssertNotNil(result.attributedText, @"a patch the shown text has no base for, %@", markdown);
        [storage setAttributedString:result.attributedText ?: [[NSAttributedString alloc] init]];
      }
      shownRevisions[i] = @(result.revision);
      XCTAssertNil(ENRMDifference(storage, [[NSTextStorage alloc] initWithAttributedString:expected]),
                   @"shown segment %lu of %@", i, markdown);
    }
  }
  XCTAssertGreaterThan(patches, states / 2, @"patched %lu of %lu", patches, states);
}

// The commonmark view's one text of the whole document, tables, quotes and code included.
- (void)testOneTextOfEveryPrefixRendersAsAFullRenderAndPatches
{
  ENRMTextRenderCache *cache = [[ENRMTextRenderCache alloc] init];
  NSTextStorage *shown = [[NSTextStorage alloc] init];
  uint64_t shownRevision = 0;
  NSUInteger patches = 0;
  NSUInteger states = 0;
  for (NSUInteger length = 1; length <= kDocument.length; length += 3) {
    NSString *markdown = [kDocument substringToIndex:length];
    MarkdownASTNode *ast = [_parser parseMarkdown:markdown flags:[ENRMMd4cFlags defaultFlags] isGFM:YES];
    [cache beginRenderWithKey:@[ @1 ]];
    ENRMRenderResult *result =
        ENRMRenderTextCached(ast.children, _config, NO, YES, 0, NSLineBreakStrategyStandard,
                             ENRMWritingDirectionModeFirstStrong, NSWritingDirectionLeftToRight, cache);
    [cache endRender];
    ENRMRenderResult *full = ENRMRenderASTNodes(ast.children, _config, NO, YES, 0, NSLineBreakStrategyStandard);
    ENRMApplyWritingDirectionMode(full.attributedText, ENRMWritingDirectionModeFirstStrong,
                                  NSWritingDirectionLeftToRight);
    states++;
    if (result.attributedText) {
      XCTAssertNil(ENRMDifference(result.attributedText, full.attributedText), @"%@", markdown);
    }
    XCTAssertEqual(result.textLength, full.attributedText.length);

    if (result.patchTail && result.patchBaseRevision == shownRevision) {
      [shown replaceCharactersInRange:NSMakeRange(result.patchStart, shown.length - result.patchStart)
                 withAttributedString:result.patchTail];
      patches++;
    } else if (result.revision != shownRevision) {
      XCTAssertNotNil(result.attributedText, @"a patch the shown text has no base for, %@", markdown);
      [shown setAttributedString:result.attributedText ?: [[NSAttributedString alloc] init]];
    }
    shownRevision = result.revision;
    XCTAssertNil(ENRMDifference(shown, [[NSTextStorage alloc] initWithAttributedString:full.attributedText]), @"%@",
                 markdown);
  }
  XCTAssertGreaterThan(patches, states / 2, @"patched %lu of %lu", patches, states);
}

- (ENRMRenderedSegment *)lastTextOf:(NSString *)markdown cache:(ENRMTextRenderCache *)cache
{
  return ENRMTextSegmentsOf([self render:markdown cache:cache]).lastObject;
}

// What the host does with a segment (EnrichedMarkdown's configureTextView).
static void ENRMShow(EnrichedMarkdownInternalText *view, ENRMRenderedSegment *segment)
{
  ENRMRenderResult *result = segment.textResult;
  if (result.patchTail && result.patchBaseRevision == view.renderedRevision) {
    [view applyAttributedTextPatch:result.patchTail from:result.patchStart];
    view.renderedRevision = result.revision;
  } else if (result.attributedText) {
    [view applyAttributedText:result.attributedText context:result.context];
    view.renderedRevision = result.revision;
  }
}

- (void)testAViewWithoutThePatchBaseKeepsItsTextAndAsksForAFullRender
{
  ENRMTextRenderCache *cache = [[ENRMTextRenderCache alloc] init];
  [self lastTextOf:@"# Title\n\nFirst" cache:cache];
  ENRMRenderedSegment *patchOnly = [self lastTextOf:@"# Title\n\nFirst para" cache:cache];
  XCTAssertNil(patchOnly.textResult.attributedText);

  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  ENRMShow(view, ENRMTextSegmentsOf([self render:@"Other" cache:nil]).lastObject);
  NSString *before = view.textView.textStorage.string;
  ENRMShow(view, patchOnly);
  XCTAssertEqualObjects(view.textView.textStorage.string, before);
  XCTAssertEqualObjects(ENRMSyncTextRevisions(@[ patchOnly ], @[ view ]), [NSIndexSet indexSetWithIndex:0]);
}

// After the cache was dropped, the next full render hands the reconciler the same segment under a
// new revision, and it keeps the view: the next patch must still apply.
- (void)testAKeptViewTakesTheNewRevisionSoTheNextPatchApplies
{
  ENRMTextRenderCache *cache = [[ENRMTextRenderCache alloc] init];
  EnrichedMarkdownInternalText *view = [[EnrichedMarkdownInternalText alloc] initWithConfig:_config];
  ENRMRenderedSegment *first = [self lastTextOf:@"# Title\n\nFirst" cache:cache];
  ENRMShow(view, first);

  [cache clear];
  ENRMRenderedSegment *again = [self lastTextOf:@"# Title\n\nFirst" cache:cache];
  XCTAssertNotEqual(first.textResult.revision, again.textResult.revision);
  XCTAssertEqual(first.signature, again.signature);
  XCTAssertEqual(ENRMSyncTextRevisions(@[ again ], @[ view ]).count, 0u);
  XCTAssertEqual(view.renderedRevision, again.textResult.revision);

  ENRMRenderedSegment *patch = [self lastTextOf:@"# Title\n\nFirst para" cache:cache];
  ENRMShow(view, patch);
  XCTAssertEqual(ENRMSyncTextRevisions(@[ patch ], @[ view ]).count, 0u);
  NSAttributedString *full =
      ENRMTextSegmentsOf([self render:@"# Title\n\nFirst para" cache:nil]).lastObject.textResult.attributedText;
  XCTAssertEqualObjects(view.textView.textStorage.string, full.string);
}

// The view keeps it: same signature and revision, and the cache keeps no copy of its text.
- (void)testAnUnchangedSegmentIsHandedBackUnderItsRevision
{
  ENRMTextRenderCache *cache = [[ENRMTextRenderCache alloc] init];
  NSArray<ENRMRenderedSegment *> *first = ENRMTextSegmentsOf([self render:kDocument cache:cache]);
  NSArray<ENRMRenderedSegment *> *second = ENRMTextSegmentsOf([self render:kDocument cache:cache]);
  XCTAssertEqual(first.count, second.count);
  for (NSUInteger i = 0; i < first.count; i++) {
    XCTAssertEqual(first[i].signature, second[i].signature);
    XCTAssertEqual(first[i].textResult.revision, second[i].textResult.revision);
    XCTAssertNil(second[i].textResult.attributedText);
  }
}

- (void)testANewKeyRendersInFull
{
  ENRMTextRenderCache *cache = [[ENRMTextRenderCache alloc] init];
  [self render:@"# Title\n\nFirst" cache:cache];
  [cache beginRenderWithKey:@[ @2 ]];
  [cache endRender];
  ENRMRenderResult *result =
      ENRMTextSegmentsOf([self render:@"# Title\n\nFirst para" cache:cache]).lastObject.textResult;
  XCTAssertNil(result.patchTail);
}

@end
