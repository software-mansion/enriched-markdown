#include "MarkdownMeasureSession.h"

#include <atomic>
#include <mutex>
#include <unordered_map>

namespace facebook::react {

namespace {

thread_local MarkdownMeasureSession *currentSession = nullptr;

// Distinct configs come from style changes and from per-message content props (link pills, image
// sources, headers); the bound is against an app that makes new ones on every render. Clearing is
// safe: keys keep counting up, and a node keeps the copy it holds.
constexpr size_t kMaxConfigs = 256;

} // namespace

InternedMeasureConfig internMarkdownMeasureConfig(folly::dynamic config) {
  static std::mutex mutex;
  static std::unordered_map<folly::dynamic, InternedMeasureConfig> configs;
  static int lastKey = 0;
  std::lock_guard<std::mutex> lock(mutex);
  if (auto it = configs.find(config); it != configs.end()) {
    return it->second;
  }
  if (configs.size() >= kMaxConfigs) {
    configs.clear();
  }
  InternedMeasureConfig interned{++lastKey, std::make_shared<const folly::dynamic>(config)};
  configs.emplace(std::move(config), interned);
  return interned;
}

int nextMarkdownMeasureTextKey() {
  static std::atomic<int> lastKey{0};
  return ++lastKey;
}

MarkdownMeasureSession *MarkdownMeasureSession::current() {
  return currentSession;
}

MarkdownMeasureSession::Scope::Scope(MarkdownMeasureSession *session) : previous_(currentSession) {
  currentSession = session;
}

MarkdownMeasureSession::Scope::~Scope() {
  currentSession = previous_;
}

} // namespace facebook::react
