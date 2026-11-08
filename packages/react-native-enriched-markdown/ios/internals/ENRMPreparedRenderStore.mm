#import "ENRMPreparedRenderStore.h"

#include <algorithm>
#include <cmath>
#include <iterator>
#include <mutex>
#include <vector>

namespace {

struct PreparedRender {
  std::weak_ptr<const void> props;
  CGFloat fontScale;
  NSWritingDirection layoutDirection;
  NSSet<NSString *> *slotIds;
  // nil once the view took it: kept so later layout passes over the same props,
  // before the shadow node learns the view mounted, do not render it again.
  id result;
};

// Only views that have not mounted yet prepare, and each takes its own on
// mount, so this bounds a burst of rows measured before one mount transaction.
constexpr size_t kCapacity = 256;

std::mutex gMutex;
std::vector<PreparedRender> gEntries;

bool SameOwner(const std::weak_ptr<const void> &entry, const std::shared_ptr<const void> &props)
{
  return !entry.owner_before(props) && !props.owner_before(entry);
}

bool SameSlotIds(NSSet<NSString *> *a, NSSet<NSString *> *b)
{
  if (a.count == 0 || b.count == 0) {
    return a.count == b.count;
  }
  return [a isEqualToSet:b];
}

bool Matches(const PreparedRender &entry, const ENRMPreparedRenderKey &key)
{
  return std::abs(entry.fontScale - key.fontScale) < 0.001 && entry.layoutDirection == key.layoutDirection &&
         SameSlotIds(entry.slotIds, key.slotIds);
}

} // namespace

@implementation ENRMPreparedRenderStore

+ (id)prepareForKey:(const ENRMPreparedRenderKey &)key render:(id (^)(void))render
{
  if (!key.props) {
    return nil;
  }
  {
    std::lock_guard<std::mutex> lock(gMutex);
    for (const auto &entry : gEntries) {
      if (SameOwner(entry.props, key.props) && (!entry.result || Matches(entry, key))) {
        return nil;
      }
    }
  }

  // Replaced and evicted renders are released after unlocking: a document's
  // graph can be large, and main may be waiting in takeForKey:.
  id result;
  @autoreleasepool {
    result = render();
    if (!result) {
      return nil;
    }
    std::vector<PreparedRender> released;
    {
      std::lock_guard<std::mutex> lock(gMutex);
      auto stale = std::stable_partition(gEntries.begin(), gEntries.end(), [&](const PreparedRender &entry) {
        return !entry.props.expired() && !SameOwner(entry.props, key.props);
      });
      std::move(stale, gEntries.end(), std::back_inserter(released));
      gEntries.erase(stale, gEntries.end());
      if (gEntries.size() >= kCapacity) {
        released.push_back(std::move(gEntries.front()));
        gEntries.erase(gEntries.begin());
      }
      gEntries.push_back({key.props, key.fontScale, key.layoutDirection, [key.slotIds copy], result});
    }
    released.clear();
  }
  return result;
}

+ (id)takeForKey:(const ENRMPreparedRenderKey &)key
{
  if (!key.props) {
    return nil;
  }
  PreparedRender taken;
  BOOL found = NO;
  {
    std::lock_guard<std::mutex> lock(gMutex);
    for (auto &entry : gEntries) {
      if (SameOwner(entry.props, key.props) && entry.result) {
        taken = entry;
        entry.result = nil;
        found = YES;
        break;
      }
    }
  }
  return found && Matches(taken, key) ? taken.result : nil;
}

@end
