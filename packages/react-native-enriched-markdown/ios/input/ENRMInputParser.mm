#import "ENRMInputParser.h"
#import "ENRMFormattingRange.h"
#import "ENRMInputCoreBridge.hpp"

@interface ENRMParseResult ()
@property (nonatomic, strong, readwrite) NSString *plainText;
@property (nonatomic, strong, readwrite) NSArray<ENRMFormattingRange *> *formattingRanges;
@property (nonatomic, strong, readwrite) NSArray<ENRMBlockRange *> *blockRanges;
@end

@implementation ENRMParseResult
@end

@implementation ENRMInputParser

- (ENRMParseResult *)parseToPlainTextAndRanges:(NSString *)markdown
{
  ENRMParseResult *parseResult = [[ENRMParseResult alloc] init];
  if (markdown.length == 0) {
    parseResult.plainText = @"";
    parseResult.formattingRanges = @[];
    parseResult.blockRanges = @[];
    return parseResult;
  }

  Markdown::Input::ParseResult parsed = Markdown::Input::parse(ENRMInputCoreBridge::toU16(markdown));

  NSMutableArray<ENRMFormattingRange *> *formattingRanges =
      [NSMutableArray arrayWithCapacity:parsed.formattingRanges.size()];
  for (const auto &range : parsed.formattingRanges) {
    NSString *url = range.type == Markdown::Input::StyleType::Link ? ENRMInputCoreBridge::toNSString(range.url) : nil;
    [formattingRanges addObject:[ENRMFormattingRange rangeWithType:(ENRMInputStyleType)range.type
                                                             range:NSMakeRange(range.start, range.end - range.start)
                                                               url:url]];
  }

  NSMutableArray<ENRMBlockRange *> *blockRanges = [NSMutableArray arrayWithCapacity:parsed.blockRanges.size()];
  for (const auto &block : parsed.blockRanges) {
    // Plain paragraphs are the default for any line a block does not claim.
    if (block.type == Markdown::Input::BlockType::Paragraph) {
      continue;
    }
    ENRMBlockRange *blockRange = [ENRMBlockRange rangeWithType:(ENRMInputBlockType)block.type
                                                         range:NSMakeRange(block.start, block.end - block.start)
                                                         level:block.level];
    blockRange.ordinal = block.ordinal;
    [blockRanges addObject:blockRange];
  }

  parseResult.plainText = ENRMInputCoreBridge::toNSString(parsed.plainText);
  parseResult.formattingRanges = formattingRanges;
  parseResult.blockRanges = blockRanges;
  return parseResult;
}

@end
