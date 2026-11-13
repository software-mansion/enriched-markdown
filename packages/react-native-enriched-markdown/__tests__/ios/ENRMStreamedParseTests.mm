#include "../../../core/cpp/parser/DocumentStore.hpp"
#import "../../ios/parser/ENRMMarkdownParser.h"
#import "../../ios/parser/MarkdownASTNode.h"
#import "../../ios/segments/RenderedMarkdownSegment.h"
#import "../../ios/utils/ENRMLinkRegexConfig.h"
#import "../../ios/utils/StreamingMarkdownFilter.h"
#import <XCTest/XCTest.h>

// A stream's finished blocks keep their nodes from one update to the next (the core's
// DocumentStore), and the parser converts and hashes only the blocks that are new.

static NSString *const kStreamed =
    @"# Setting up\n\nTo get started, install **the tools** and read the [guide](https://e.com).\n\n"
    @"- Clone the repo\n- Install\n\n> A quote with `code`.\n\n```js\nconst a = 1;\n\nconst b = 2;\n```\n\n"
    @"![image](https://e.com/a.png)\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nThat's it, you now have a **working "
    @"setup**.\n\nOne more paragraph, still arriving";

@interface ENRMStreamedParseTests : XCTestCase
@end

@implementation ENRMStreamedParseTests {
  ENRMMarkdownParser *_parser;
}

- (void)setUp
{
  _parser = [[ENRMMarkdownParser alloc] init];
}

static void ENRMDescribe(MarkdownASTNode *node, NSMutableString *out)
{
  [out appendFormat:@"(%ld %@", (long)node.type, node.content ?: @""];
  for (NSString *key in [node.attributes.allKeys sortedArrayUsingSelector:@selector(compare:)]) {
    [out appendFormat:@" {%@=%@}", key, node.attributes[key]];
  }
  for (MarkdownASTNode *child in node.children) {
    ENRMDescribe(child, out);
  }
  [out appendString:@")"];
}

static NSString *ENRMDescription(MarkdownASTNode *node)
{
  NSMutableString *out = [NSMutableString string];
  ENRMDescribe(node, out);
  return out;
}

- (NSString *)snapshotOf:(NSString *)markdown
{
  return ENRMRenderableMarkdownForStreaming(markdown, [ENRMMd4cFlags defaultFlags], ENRMTableStreamingModeProgressive,
                                            ENRMCodeBlockStreamingModeProgressive, ENRMMediaStreamingModeProgressive,
                                            NULL);
}

// A link pattern that matches what `linkRegex` matches (or nothing), written differently each time:
// the parser shares no blocks with a conversion made under another pattern, so it converts every
// block again.
- (MarkdownASTNode *)parseAfresh:(NSString *)snapshot linkRegex:(ENRMLinkRegexConfig *)linkRegex
{
  static NSUInteger count = 0;
  NSString *pattern =
      [NSString stringWithFormat:@"(?:%@)(?:){%lu}", linkRegex ? linkRegex.pattern : @"(?!)", (unsigned long)count++];
  ENRMLinkRegexConfig *afresh = [ENRMLinkRegexConfig cachedConfigWithPattern:pattern
                                                             caseInsensitive:linkRegex.caseInsensitive
                                                                      dotAll:linkRegex.dotAll];
  return [_parser parseMarkdown:snapshot
                          flags:[ENRMMd4cFlags defaultFlags]
                          isGFM:YES
                      linkRegex:afresh
            inlineCodeLinkRegex:afresh
             activeBlockSlotIds:nil
                 annotateImages:NO];
}

- (MarkdownASTNode *)parseAfresh:(NSString *)snapshot
{
  return [self parseAfresh:snapshot linkRegex:nil];
}

- (void)testAStreamKeepsTheNodesOfItsFinishedBlocks
{
  MarkdownASTNode *previous = nil;
  NSUInteger reused = 0;
  NSUInteger updates = 0;
  for (NSUInteger length = 5; length <= kStreamed.length; length = MIN(length + 7, kStreamed.length)) {
    NSString *snapshot = [self snapshotOf:[kStreamed substringToIndex:length]];
    MarkdownASTNode *root = [_parser parseMarkdown:snapshot flags:[ENRMMd4cFlags defaultFlags] isGFM:YES];
    XCTAssertEqualObjects(ENRMDescription(root), ENRMDescription([self parseAfresh:snapshot]), @"%@", snapshot);

    NSUInteger same = 0;
    while (same < previous.children.count && same < root.children.count &&
           previous.children[same] == root.children[same]) {
      same++;
    }
    // Every block but the ones still arriving: what follows the last line that starts a block of
    // its own after a blank line (a paragraph and its list, a quote and its code block).
    XCTAssertGreaterThanOrEqual(same + 3, previous.children.count, @"%@", snapshot);
    reused += same;
    updates++;
    previous = root;
    if (length == kStreamed.length) {
      break;
    }
  }
  XCTAssertGreaterThan(reused, updates * 2);
}

// Links are recognized in the blocks converted anew; the ones taken over keep theirs.
- (void)testAStreamWithLinkRecognitionConvertsAsAWhole
{
  ENRMLinkRegexConfig *regex = [ENRMLinkRegexConfig cachedConfigWithPattern:@"repo|setup|code"
                                                            caseInsensitive:NO
                                                                     dotAll:NO];
  MarkdownASTNode *previous = nil;
  NSUInteger reused = 0;
  for (NSUInteger length = 5; length <= kStreamed.length; length = MIN(length + 7, kStreamed.length)) {
    NSString *snapshot = [self snapshotOf:[kStreamed substringToIndex:length]];
    MarkdownASTNode *root = [_parser parseMarkdown:snapshot
                                             flags:[ENRMMd4cFlags defaultFlags]
                                             isGFM:YES
                                         linkRegex:regex
                               inlineCodeLinkRegex:regex];
    XCTAssertEqualObjects(ENRMDescription(root), ENRMDescription([self parseAfresh:snapshot linkRegex:regex]), @"%@",
                          snapshot);
    for (NSUInteger i = 0; i < previous.children.count && i < root.children.count; i++) {
      if (previous.children[i] != root.children[i]) {
        break;
      }
      reused++;
    }
    previous = root;
    if (length == kStreamed.length) {
      break;
    }
  }
  XCTAssertGreaterThan(reused, (NSUInteger)0);
  XCTAssertNotEqualObjects(ENRMDescription(previous), ENRMDescription([self parseAfresh:[self snapshotOf:kStreamed]]));
}

- (MarkdownASTNode *)parse:(NSString *)snapshot slots:(NSSet<NSString *> *)slotIds
{
  return [_parser parseMarkdown:snapshot
                          flags:[ENRMMd4cFlags defaultFlags]
                          isGFM:YES
                      linkRegex:nil
            inlineCodeLinkRegex:nil
             activeBlockSlotIds:slotIds
                 annotateImages:NO];
}

// A slot that becomes active, as when a renderer's code block arrives, converts its block again and
// keeps the blocks before it.
- (void)testANewActiveSlotKeepsTheBlocksBeforeIt
{
  NSString *snapshot =
      [self snapshotOf:@"Intro.\n\n```js\nlet a;\n```\n\nMiddle.\n\n```js\nlet b;\n```\n\nStill arriv"];
  auto document = Markdown::DocumentStore::shared().parse(std::string(snapshot.UTF8String), {}, true);
  XCTAssertEqual(document->blocks.slots.size(), 2u);
  NSString *first = @(document->blocks.slots[0].id.c_str());
  NSString *second = @(document->blocks.slots[1].id.c_str());

  MarkdownASTNode *none = [self parse:snapshot slots:nil];
  MarkdownASTNode *one = [self parse:snapshot slots:[NSSet setWithObject:first]];
  MarkdownASTNode *both = [self parse:snapshot slots:[NSSet setWithObjects:first, second, nil]];
  XCTAssertEqual(none.children.count, 5u);

  XCTAssertEqual(one.children[0], none.children[0]);
  XCTAssertNotEqual(one.children[1], none.children[1]);
  XCTAssertEqualObjects(one.children[1].attributes[@"blockSlotId"], first);
  XCTAssertNil(none.children[1].attributes[@"blockSlotId"]);

  for (NSUInteger i = 0; i < 3; i++) {
    XCTAssertEqual(both.children[i], one.children[i]);
  }
  XCTAssertNotEqual(both.children[3], one.children[3]);
  XCTAssertEqualObjects(both.children[3].attributes[@"blockSlotId"], second);
  XCTAssertNil(one.children[3].attributes[@"blockSlotId"]);
}

- (void)testASignatureIsComputedOncePerNode
{
  MarkdownASTNode *root = [_parser parseMarkdown:@"# Title\n\nA **paragraph**."];
  MarkdownASTNode *paragraph = root.children.lastObject;
  XCTAssertEqual(paragraph.cachedSignature, (uint64_t)0);
  uint64_t signature = ENRMSignatureForNode(paragraph);
  XCTAssertEqual(paragraph.cachedSignature, signature);
  XCTAssertEqual(ENRMSignatureForNode(paragraph), signature);

  // The same content hashes the same, kept or not.
  MarkdownASTNode *again = [self parseAfresh:@"# Title\n\nA **paragraph**."].children.lastObject;
  XCTAssertNotEqual(again, paragraph);
  XCTAssertEqual(ENRMSignatureForNode(again), signature);
}

@end
