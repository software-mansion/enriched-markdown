#pragma once

#import "ENRMBlockRange.h"
#import "ENRMFormattingRange.h"

NS_ASSUME_NONNULL_BEGIN

@interface ENRMMarkdownSerializer : NSObject

+ (NSString *)serializePlainText:(NSString *)text ranges:(NSArray<ENRMFormattingRange *> *)ranges;

/// Block-aware serialization: also writes each line's block marker (`# `, `- `,
/// `1. `), derived from the block's type, level and ordinal. Blocks must be one
/// per line. With empty `blockRanges` the output is identical to the inline-only
/// overload. Plain text that would read as markup is escaped.
+ (NSString *)serializePlainText:(NSString *)text
                          ranges:(NSArray<ENRMFormattingRange *> *)ranges
                     blockRanges:(NSArray<ENRMBlockRange *> *)blockRanges;

@end

NS_ASSUME_NONNULL_END
