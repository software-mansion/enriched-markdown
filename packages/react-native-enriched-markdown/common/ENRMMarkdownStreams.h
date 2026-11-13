#pragma once
#include <algorithm>
#include <memory>
#include <mutex>
#include <string>
#include <string_view>
#include <unordered_map>

namespace facebook::react {

/// The text of the streams JS writes to (createMarkdownStream), by id. A stream only grows, so its
/// first `length` bytes are the same text at every later point: props naming (id, length) name one
/// text, which measurement and rendering both read. A reset makes a new stream.
class ENRMMarkdownStreams {
public:
  /// One for the process: the component descriptors are also compiled into the app's library on
  /// Android, so this is defined in ENRMMarkdownStreams.cpp, not inline.
  static ENRMMarkdownStreams &shared();

  int create(std::string text) {
    std::lock_guard<std::mutex> lock(mutex_);
    int id = nextId_++;
    buffers_.emplace(id, std::move(text));
    return id;
  }

  /// The stream's length after appending `chunk`; 0 for a stream that is gone.
  size_t append(int id, std::string_view chunk) {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = buffers_.find(id);
    if (it == buffers_.end()) {
      return 0;
    }
    it->second.append(chunk);
    return it->second.size();
  }

  void dispose(int id) {
    std::lock_guard<std::mutex> lock(mutex_);
    buffers_.erase(id);
  }

  /// The stream's first `length` bytes (as many as it has); empty for a stream that is gone.
  std::string prefix(int id, size_t length) const {
    std::lock_guard<std::mutex> lock(mutex_);
    auto it = buffers_.find(id);
    if (it == buffers_.end()) {
      return {};
    }
    return it->second.substr(0, length);
  }

private:
  mutable std::mutex mutex_;
  std::unordered_map<int, std::string> buffers_;
  int nextId_ = 1;
};

/// Called from the component descriptors' cloneProps: props bound to a stream (`streamId`) take
/// their `markdown` from it, so everything downstream reads a plain `markdown` prop. Unchanged
/// (id, length) keeps the text the props were copied with.
template <typename PropsT, typename BaseProps>
inline std::shared_ptr<const BaseProps> ENRMResolveStreamedMarkdown(const std::shared_ptr<const BaseProps> &sourceProps,
                                                                    const std::shared_ptr<const BaseProps> &props) {
  const auto &typed = static_cast<const PropsT &>(*props);
  if (typed.streamId == 0) {
    return props;
  }
  // streamId != 0 means the base built these props; the shared defaults have 0.
  auto resolved = std::const_pointer_cast<PropsT>(std::static_pointer_cast<const PropsT>(props));
  const auto *source = static_cast<const PropsT *>(sourceProps.get());
  // React sent other props: the text is the source's, unless a full prop set brought the placeholder.
  std::string markdown =
      source != nullptr && source->streamId == typed.streamId && source->streamLength == typed.streamLength
          ? source->markdown
          : ENRMMarkdownStreams::shared().prefix(typed.streamId, static_cast<size_t>(std::max(typed.streamLength, 0)));
  if (resolved->markdown != markdown) {
    resolved->markdown = std::move(markdown);
#ifdef RN_SERIALIZABLE_STATE
    // Android mounts views from the raw props.
    resolved->rawProps["markdown"] = resolved->markdown;
#endif
  }
  return props;
}

} // namespace facebook::react
