#include "../../ios/internals/MeasurementCache.h"
#import <XCTest/XCTest.h>

using facebook::react::CachedSize;
using facebook::react::MeasurementCache;
using facebook::react::MeasurementCacheKey;

static MeasurementCacheKey ENRMMeasurementCacheTestKey(char fill, size_t length)
{
  MeasurementCacheKey key{};
  key.markdown = std::string(length, fill);
  return key;
}

@interface ENRMMeasurementCacheTests : XCTestCase
@end

@implementation ENRMMeasurementCacheTests

- (void)testEvictsLeastRecentlyUsedDocumentsOverTheKeyByteBudget
{
  auto &cache = MeasurementCache::shared();
  // Three 3 MiB documents exceed the 8 MiB budget.
  MeasurementCacheKey keys[3];
  for (int i = 0; i < 3; i++) {
    keys[i] = ENRMMeasurementCacheTestKey('a' + i, 3 * 1024 * 1024);
  }
  CachedSize size;
  for (int i = 0; i < 2; i++) {
    cache.set(keys[i], {CGFloat(i), 20});
  }
  XCTAssertTrue(cache.get(keys[0], size));

  cache.set(keys[2], {2, 20});

  XCTAssertFalse(cache.get(keys[1], size));
  for (int i : {0, 2}) {
    XCTAssertTrue(cache.get(keys[i], size), @"key %d", i);
    XCTAssertEqual(size.width, CGFloat(i));
  }
  for (const auto &key : keys) {
    cache.removeMatchingMarkdown(key.markdown);
  }
}

- (void)testSkipsDocumentsLargerThanTheBudgetWithoutEvicting
{
  auto &cache = MeasurementCache::shared();
  MeasurementCacheKey small = ENRMMeasurementCacheTestKey('s', 16);
  MeasurementCacheKey huge = ENRMMeasurementCacheTestKey('z', 9 * 1024 * 1024);
  CachedSize size;
  cache.set(small, {1, 1});

  cache.set(huge, {2, 2});

  XCTAssertFalse(cache.get(huge, size));
  XCTAssertTrue(cache.get(small, size));
  cache.removeMatchingMarkdown(small.markdown);
  cache.removeMatchingMarkdown(huge.markdown);
}

@end
