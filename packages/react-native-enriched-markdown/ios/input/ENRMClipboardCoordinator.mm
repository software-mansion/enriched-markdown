#import "ENRMClipboardCoordinator.h"
#import "ENRMBlockStore.h"
#import "ENRMFormattingStore.h"
#import "ENRMMarkdownSerializer.h"

@implementation ENRMClipboardCoordinator {
  ENRMFormattingStore *_formattingStore;
  ENRMBlockStore *_blockStore;
  id<ENRMTransientRangeProvider> _transientRangeProvider;
}

- (instancetype)initWithFormattingStore:(ENRMFormattingStore *)formattingStore
                             blockStore:(ENRMBlockStore *)blockStore
                 transientRangeProvider:(id<ENRMTransientRangeProvider>)transientRangeProvider
{
  if (self = [super init]) {
    _formattingStore = formattingStore;
    _blockStore = blockStore;
    _transientRangeProvider = transientRangeProvider;
  }
  return self;
}

- (NSArray<ENRMFormattingRange *> *)allRangesIncludingTransient
{
  NSArray<ENRMFormattingRange *> *transient = [_transientRangeProvider allTransientFormattingRanges];
  if (transient.count == 0) {
    return _formattingStore.allRanges;
  }
  NSMutableArray<ENRMFormattingRange *> *merged = [_formattingStore.allRanges mutableCopy];
  [merged addObjectsFromArray:transient];
  return merged;
}

- (NSString *)serializeText:(NSString *)text
                     ranges:(NSArray<ENRMFormattingRange *> *)ranges
                blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges
{
  return [ENRMMarkdownSerializer serializePlainText:text ranges:ranges blockRanges:blockRanges];
}

- (NSString *)serializeFullDocument:(NSString *)plainText
{
  return [self serializeText:plainText ranges:[self allRangesIncludingTransient] blockRanges:_blockStore.allRanges];
}

- (nullable NSString *)serializeSelectedRange:(NSRange)selection inText:(NSString *)fullText
{
  if (selection.length == 0) {
    return nil;
  }

  NSString *selectedText = [fullText substringWithRange:selection];
  NSUInteger selEnd = NSMaxRange(selection);

  NSMutableArray<ENRMFormattingRange *> *clippedRanges = [NSMutableArray array];
  for (ENRMFormattingRange *range in [self allRangesIncludingTransient]) {
    NSUInteger rangeStart = range.range.location;
    NSUInteger rangeEnd = NSMaxRange(range.range);
    if (rangeEnd <= selection.location || rangeStart >= selEnd) {
      continue;
    }
    NSUInteger clippedStart = MAX(rangeStart, selection.location);
    NSUInteger clippedEnd = MIN(rangeEnd, selEnd);
    NSRange shifted = NSMakeRange(clippedStart - selection.location, clippedEnd - clippedStart);
    [clippedRanges addObject:[ENRMFormattingRange rangeWithType:range.type range:shifted url:range.url]];
  }

  NSMutableArray<ENRMBlockRange *> *clippedBlockRanges = [NSMutableArray array];
  for (ENRMBlockRange *blockRange in _blockStore.allRanges) {
    NSUInteger rangeStart = blockRange.range.location;
    NSUInteger rangeEnd = NSMaxRange(blockRange.range);
    if (rangeEnd <= selection.location || rangeStart >= selEnd) {
      continue;
    }
    NSUInteger clippedStart = MAX(rangeStart, selection.location);
    NSUInteger clippedEnd = MIN(rangeEnd, selEnd);
    NSRange shifted = NSMakeRange(clippedStart - selection.location, clippedEnd - clippedStart);
    ENRMBlockRange *clipped = [ENRMBlockRange rangeWithType:blockRange.type range:shifted level:blockRange.level];
    // The core writes the ordinal it is given, so a copy of items 3 and 4 keeps "3." and "4.".
    clipped.ordinal = blockRange.ordinal;
    [clippedBlockRanges addObject:clipped];
  }

  return [self serializeText:selectedText ranges:clippedRanges blockRanges:clippedBlockRanges];
}

@end
