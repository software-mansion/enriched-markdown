#pragma once

#include <folly/dynamic.h>
#include <memory>
#include <string>

namespace facebook::react {

// Only held and cast here; the shadow nodes that instantiate update() see the full type.
class Props;

// A layout config interned by value: every view with the same style shares its key and one copy.
struct InternedMeasureConfig {
  int key{0};
  std::shared_ptr<const folly::dynamic> config;
};

// Process-wide keys: one per distinct layout config, one per distinct markdown. Keys only count
// up, so a key never names two values.
InternedMeasureConfig internMarkdownMeasureConfig(folly::dynamic config);
int nextMarkdownMeasureTextKey();

/**
 * What a markdown view's measurement crosses over to Kotlin with: two keys in place of its props.
 * Kotlin keeps what it parsed under them and pulls the markdown or the layout config
 * (MeasurementStore.nativeMeasureMarkdown / nativeMeasureConfig) from the session installed around
 * the call only when it doesn't have them. The markdown then crosses once per update instead of on
 * every measure, and the style is parsed once per distinct style.
 */
struct MarkdownMeasureKeys {
  // The props the keys are for. Held, not just compared: a freed props object's address can come
  // back for the next one. This keeps the last measured props alive until the next ones.
  std::shared_ptr<const Props> props;
  // The interned copy, so a clone of the node (every chunk, every Yoga ownership clone) copies a
  // pointer and equal configs are held once.
  std::shared_ptr<const folly::dynamic> config;
  int configKey{0};
  int textKey{0};

  // Brings the keys up to `props`, the next props of the same node. `layoutConfig` serializes the
  // props that lay the document out besides the markdown (conversions.h). New props, as every
  // streamed chunk brings, pay one serialization and one comparison of that config.
  template <typename P, typename LayoutConfig>
  void update(const std::shared_ptr<const Props> &next, LayoutConfig layoutConfig) {
    if (props == next) {
      return;
    }
    const auto *previous = static_cast<const P *>(props.get());
    const auto &nextProps = static_cast<const P &>(*next);
    if (!previous || previous->markdown != nextProps.markdown) {
      textKey = nextMarkdownMeasureTextKey();
    }
    auto nextConfig = layoutConfig(nextProps);
    if (!config || nextConfig != *config) {
      auto interned = internMarkdownMeasureConfig(std::move(nextConfig));
      configKey = interned.key;
      config = std::move(interned.config);
    }
    props = next;
  }

  // What measurement sends in place of the props.
  folly::dynamic toDynamic() const {
    return folly::dynamic::object("configKey", configKey)("textKey", textKey);
  }
};

/** The inputs of the measurement in progress on this thread, for Kotlin to pull. */
class MarkdownMeasureSession {
public:
  MarkdownMeasureSession(const std::string &markdown, const folly::dynamic &config)
      : markdown_(markdown), config_(config) {}

  static MarkdownMeasureSession *current();

  // Installs `session` as current for the enclosing scope.
  class Scope {
  public:
    explicit Scope(MarkdownMeasureSession *session);
    ~Scope();

  private:
    MarkdownMeasureSession *previous_;
  };

  const std::string &markdown() const {
    return markdown_;
  }

  const folly::dynamic &config() const {
    return config_;
  }

private:
  const std::string &markdown_;
  const folly::dynamic &config_;
};

} // namespace facebook::react
