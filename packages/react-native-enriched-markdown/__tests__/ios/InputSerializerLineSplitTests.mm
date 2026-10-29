#import "../../ios/input/ENRMBlockRange.h"
#import "../../ios/input/ENRMFormattingRange.h"
#import "../../ios/input/ENRMMarkdownSerializer.h"
#import <XCTest/XCTest.h>

@interface ENRMInputSerializerLineSplitTests : XCTestCase
@end

@implementation ENRMInputSerializerLineSplitTests

- (NSString *)serialize:(NSString *)text
             boldRanges:(NSArray<NSValue *> *)boldRanges
            blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
{
  NSMutableArray<ENRMFormattingRange *> *ranges = [NSMutableArray array];
  for (NSValue *value in boldRanges) {
    [ranges addObject:[ENRMFormattingRange rangeWithType:ENRMInputStyleTypeStrong range:value.rangeValue]];
  }
  return [ENRMMarkdownSerializer serializePlainText:text
                                             ranges:ranges
                                        blockRanges:blockRanges
                                blockPrefixProvider:^NSString *(ENRMBlockRange *blockRange) {
                                  switch (blockRange.type) {
                                    case ENRMInputBlockTypeUnorderedListItem:
                                      return @"- ";
                                    case ENRMInputBlockTypeHeading1:
                                      return @"# ";
                                    default:
                                      return @"";
                                  }
                                }];
}

- (void)testBoldAcrossListItemsClosesInEachItem
{
  NSString *markdown = [self serialize:@"One\nTwo"
                            boldRanges:@[ [NSValue valueWithRange:NSMakeRange(0, 7)] ]
                           blockRanges:@[
                             [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem range:NSMakeRange(0, 3)],
                             [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem range:NSMakeRange(4, 3)],
                           ]];
  XCTAssertEqualObjects(markdown, @"- **One**\n- **Two**");
}

- (NSArray<ENRMBlockRange *> *)twoBulletItems
{
  return @[
    [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem range:NSMakeRange(0, 3)],
    [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem range:NSMakeRange(4, 3)],
  ];
}

- (void)testEveryInlineStyleAcrossListItemsClosesInEachItem
{
  NSDictionary<NSNumber *, NSString *> *delimiters = @{
    @(ENRMInputStyleTypeEmphasis) : @"*",
    @(ENRMInputStyleTypeUnderline) : @"_",
    @(ENRMInputStyleTypeStrikethrough) : @"~~",
    @(ENRMInputStyleTypeSpoiler) : @"||",
  };
  [delimiters enumerateKeysAndObjectsUsingBlock:^(NSNumber *type, NSString *delimiter, BOOL *stop) {
    ENRMFormattingRange *range = [ENRMFormattingRange rangeWithType:(ENRMInputStyleType)type.integerValue
                                                              range:NSMakeRange(0, 7)];
    NSString *markdown =
        [ENRMMarkdownSerializer serializePlainText:@"One\nTwo"
                                            ranges:@[ range ]
                                       blockRanges:[self twoBulletItems]
                               blockPrefixProvider:^NSString *(ENRMBlockRange *blockRange) { return @"- "; }];
    NSString *expected = [NSString stringWithFormat:@"- %1$@One%1$@\n- %1$@Two%1$@", delimiter];
    XCTAssertEqualObjects(markdown, expected, @"style %@", type);
  }];
}

- (void)testLinkAcrossListItemsClosesInEachItem
{
  ENRMFormattingRange *link = [ENRMFormattingRange rangeWithType:ENRMInputStyleTypeLink
                                                           range:NSMakeRange(0, 7)
                                                             url:@"https://example.com"];
  NSString *markdown =
      [ENRMMarkdownSerializer serializePlainText:@"One\nTwo"
                                          ranges:@[ link ]
                                     blockRanges:[self twoBulletItems]
                             blockPrefixProvider:^NSString *(ENRMBlockRange *blockRange) { return @"- "; }];
  XCTAssertEqualObjects(markdown, @"- [One](https://example.com)\n- [Two](https://example.com)");
}

- (void)testBoldFromAHeadingIntoAParagraphClosesInTheHeading
{
  NSString *markdown = [self serialize:@"Title\nBody"
                            boldRanges:@[ [NSValue valueWithRange:NSMakeRange(0, 10)] ]
                           blockRanges:@[ [ENRMBlockRange rangeWithType:ENRMInputBlockTypeHeading1
                                                                  range:NSMakeRange(0, 5)
                                                                  level:1] ]];
  XCTAssertEqualObjects(markdown, @"# **Title**\n**Body**");
}

- (void)testBoldAcrossParagraphsSkipsTheBlankLine
{
  NSString *markdown = [self serialize:@"One\n\nTwo"
                            boldRanges:@[ [NSValue valueWithRange:NSMakeRange(0, 8)] ]
                           blockRanges:@[]];
  XCTAssertEqualObjects(markdown, @"**One**\n\n**Two**");
}

- (void)testBoldInsideOneLineIsUnchanged
{
  NSString *markdown = [self serialize:@"One\nTwo"
                            boldRanges:@[ [NSValue valueWithRange:NSMakeRange(4, 3)] ]
                           blockRanges:@[
                             [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem range:NSMakeRange(0, 3)],
                             [ENRMBlockRange rangeWithType:ENRMInputBlockTypeUnorderedListItem range:NSMakeRange(4, 3)],
                           ]];
  XCTAssertEqualObjects(markdown, @"- One\n- **Two**");
}

@end
