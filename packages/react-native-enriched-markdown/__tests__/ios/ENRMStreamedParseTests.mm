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

// A slot id no block has changes nothing in the tree, and a new one each time makes the parser
// convert every block again.
- (MarkdownASTNode *)parseAfresh:(NSString *)snapshot linkRegex:(ENRMLinkRegexConfig *)linkRegex
{
  static NSUInteger count = 0;
  NSString *unused = [NSString stringWithFormat:@"unused-%lu", (unsigned long)count++];
  return [_parser parseMarkdown:snapshot
                          flags:[ENRMMd4cFlags defaultFlags]
                          isGFM:YES
                      linkRegex:linkRegex
            inlineCodeLinkRegex:linkRegex
             activeBlockSlotIds:[NSSet setWithObject:unused]
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
