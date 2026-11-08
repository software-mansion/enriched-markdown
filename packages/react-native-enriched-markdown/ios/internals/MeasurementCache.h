#pragma once

#include <CoreGraphics/CGBase.h>
#include <React/RCTUtils.h>
#include <functional>
#include <list>
#include <memory>
#include <mutex>
#include <optional>
#include <react/renderer/graphics/Float.h>
#include <string>
#include <tuple>
#include <type_traits>
#include <unordered_map>

namespace facebook::react {

struct HashUtils {

  static inline size_t combine(size_t h, size_t v)
  {
    return h ^ (v + 0x9e3779b97f4a7c15ULL + (h << 6) + (h >> 2));
  }

  template <typename T> static inline void hash_one(size_t &seed, const T &v)
  {
    seed = combine(seed, std::hash<T>{}(v));
  }
};

enum class MarkdownFlavor : uint8_t {
  CommonMark = 0,
  GitHub = 1,
};

struct MeasurementCacheKey {
  std::string markdown;
  CGFloat maxWidth;
  bool allowTrailingMargin;
  bool allowFontScaling;
  double maxFontSizeMultiplier;
  bool md4cFlagsUnderline;
  bool md4cFlagsSuperscript;
  bool md4cFlagsSubscript;
  bool md4cFlagsStrikethrough;
  bool md4cFlagsHighlight;
  bool md4cFlagsLatexMath;
  bool md4cFlagsHardSoftBreaks;
  bool md4cFlagsPreserveBlankLines;
  bool md4cFlagsAdmonitions;
  size_t styleFingerprint;
  size_t linkPillContentFingerprint;
  // Overridden image sources change block image heights (maxHeight/aspectRatio sizing).
  size_t imageSourcesFingerprint;
  // Code blocks the user wrapped (view state, not props); 0 when none.
  size_t wrappedCodeBlocksFingerprint;
  CGFloat fontScale;
  MarkdownFlavor flavor;
  std::string lineBreakStrategyIOS;
  std::string writingDirection;
  int numberOfLines;
  std::string ellipsizeMode;
  std::string linkRegexKey;
  std::string inlineCodeLinkRegexKey;

  bool operator==(const MeasurementCacheKey &other) const
  {
    return std::tie(markdown, maxWidth, allowTrailingMargin, allowFontScaling, maxFontSizeMultiplier,
                    md4cFlagsUnderline, md4cFlagsSuperscript, md4cFlagsSubscript, md4cFlagsStrikethrough,
                    md4cFlagsHighlight, md4cFlagsLatexMath, md4cFlagsHardSoftBreaks, md4cFlagsPreserveBlankLines,
                    md4cFlagsAdmonitions, styleFingerprint, linkPillContentFingerprint, imageSourcesFingerprint,
                    wrappedCodeBlocksFingerprint, fontScale, flavor, lineBreakStrategyIOS, writingDirection,
                    numberOfLines, ellipsizeMode, linkRegexKey, inlineCodeLinkRegexKey) ==
           std::tie(other.markdown, other.maxWidth, other.allowTrailingMargin, other.allowFontScaling,
                    other.maxFontSizeMultiplier, other.md4cFlagsUnderline, other.md4cFlagsSuperscript,
                    other.md4cFlagsSubscript, other.md4cFlagsStrikethrough, other.md4cFlagsHighlight,
                    other.md4cFlagsLatexMath, other.md4cFlagsHardSoftBreaks, other.md4cFlagsPreserveBlankLines,
                    other.md4cFlagsAdmonitions, other.styleFingerprint, other.linkPillContentFingerprint,
                    other.imageSourcesFingerprint, other.wrappedCodeBlocksFingerprint, other.fontScale, other.flavor,
                    other.lineBreakStrategyIOS, other.writingDirection, other.numberOfLines, other.ellipsizeMode,
                    other.linkRegexKey, other.inlineCodeLinkRegexKey);
  }
};

struct MeasurementCacheKeyHash {
  size_t operator()(const MeasurementCacheKey &key) const
  {
    size_t h = 0;
    HashUtils::hash_one(h, key.markdown);
    HashUtils::hash_one(h, key.maxWidth);
    HashUtils::hash_one(h, key.allowTrailingMargin);
    HashUtils::hash_one(h, key.allowFontScaling);
    HashUtils::hash_one(h, key.maxFontSizeMultiplier);
    HashUtils::hash_one(h, key.md4cFlagsUnderline);
    HashUtils::hash_one(h, key.md4cFlagsSuperscript);
    HashUtils::hash_one(h, key.md4cFlagsSubscript);
    HashUtils::hash_one(h, key.md4cFlagsStrikethrough);
    HashUtils::hash_one(h, key.md4cFlagsHighlight);
    HashUtils::hash_one(h, key.md4cFlagsLatexMath);
    HashUtils::hash_one(h, key.md4cFlagsHardSoftBreaks);
    HashUtils::hash_one(h, key.md4cFlagsPreserveBlankLines);
    HashUtils::hash_one(h, key.md4cFlagsAdmonitions);
    HashUtils::hash_one(h, key.styleFingerprint);
    HashUtils::hash_one(h, key.linkPillContentFingerprint);
    HashUtils::hash_one(h, key.imageSourcesFingerprint);
    HashUtils::hash_one(h, key.wrappedCodeBlocksFingerprint);
    HashUtils::hash_one(h, key.fontScale);
    HashUtils::hash_one(h, static_cast<uint8_t>(key.flavor));
    HashUtils::hash_one(h, key.lineBreakStrategyIOS);
    HashUtils::hash_one(h, key.writingDirection);
    HashUtils::hash_one(h, key.numberOfLines);
    HashUtils::hash_one(h, key.ellipsizeMode);
    HashUtils::hash_one(h, key.linkRegexKey);
    HashUtils::hash_one(h, key.inlineCodeLinkRegexKey);
    return h;
  }
};

struct CachedSize {
  CGFloat width;
  CGFloat height;
};

template <typename StyleStruct> inline size_t computeStyleFingerprint(const StyleStruct &s)
{
  size_t h = 0;
  auto hashFields = [&](auto... args) { (HashUtils::hash_one(h, args), ...); };

  auto hashTextLayout = [&](const auto &item) {
    hashFields(item.fontFamily, item.fontSize, item.fontWeight, item.marginTop, item.marginBottom, item.lineHeight);
  };

  // Block Elements
  hashTextLayout(s.paragraph);
  hashFields(s.paragraph.textAlign);
  hashTextLayout(s.h1);
  hashFields(s.h1.textAlign);
  hashTextLayout(s.h2);
  hashFields(s.h2.textAlign);
  hashTextLayout(s.h3);
  hashFields(s.h3.textAlign);
  hashTextLayout(s.h4);
  hashFields(s.h4.textAlign);
  hashTextLayout(s.h5);
  hashFields(s.h5.textAlign);
  hashTextLayout(s.h6);
  hashFields(s.h6.textAlign);

  hashTextLayout(s.blockquote);
  hashFields(s.blockquote.borderWidth, s.blockquote.gapWidth, s.blockquote.padding, s.blockquote.borderRadius);

  hashTextLayout(s.list);
  hashFields(s.list.bulletSize, s.list.markerMinWidth, s.list.markerFontWeight, s.list.gapWidth, s.list.marginLeft,
             s.list.itemSpacing);

  // Code & Inlines
  hashFields(s.codeBlock.fontFamily, s.codeBlock.fontSize, s.codeBlock.fontWeight, s.codeBlock.marginTop,
             s.codeBlock.marginBottom, s.codeBlock.lineHeight, s.codeBlock.padding, s.codeBlock.borderRadius,
             s.codeBlock.borderWidth);
  hashFields(s.code.fontFamily, s.code.fontSize);
  hashFields(s.link.fontFamily, s.strong.fontFamily, s.strong.fontWeight, s.em.fontFamily, s.em.fontStyle);
  // Variants change link metrics: a font family, or a pill box around the label.
  for (const auto &variant : s.linkVariants) {
    hashFields(variant.pattern, variant.fontFamily, variant.pill.enabled, variant.pill.label, variant.pill.iconUri,
               variant.pill.paddingHorizontal, variant.pill.paddingVertical, variant.pill.lineHeight,
               variant.pill.borderWidth, variant.pill.maxWidth);
  }
  hashFields(s.highlight.backgroundColor, s.highlight.color);

  // Visual/Spacing Elements
  hashFields(s.image.height, s.image.maxHeight, s.image.aspectRatio, s.image.marginTop, s.image.marginBottom);
  hashFields(s.video.marginTop, s.video.marginBottom, s.video.borderRadius, s.video.aspectRatio,
             s.video.backgroundColor);
  hashFields(s.inlineImage.size);
  hashFields(s.thematicBreak.height, s.thematicBreak.marginTop, s.thematicBreak.marginBottom);

  // Complex Components
  hashTextLayout(s.table);
  hashFields(s.table.headerFontFamily, s.table.cellPaddingHorizontal, s.table.cellPaddingVertical, s.table.borderWidth,
             s.table.borderRadius, s.table.horizontalOverflow);
  hashFields(s.math.fontSize, s.math.padding, s.math.marginTop, s.math.marginBottom, s.math.textAlign);
  hashFields(s.taskList.checkboxSize, s.taskList.checkboxBorderRadius);

  return h;
}

// Pill labels and icons (the `linkPillContent` prop) change link widths.
template <typename ContentVector> inline size_t computeLinkPillContentFingerprint(const ContentVector &content)
{
  size_t h = 0;
  for (const auto &entry : content) {
    HashUtils::hash_one(h, entry.url);
    HashUtils::hash_one(h, entry.label);
    HashUtils::hash_one(h, entry.iconUri);
  }
  return h;
}

// Overridden image sources (the `imageSources` prop) decide which image loads, so its box height.
template <typename SourceVector> inline size_t computeImageSourcesFingerprint(const SourceVector &sources)
{
  size_t h = 0;
  for (const auto &source : sources) {
    HashUtils::hash_one(h, source.id);
    HashUtils::hash_one(h, source.uri);
    for (const auto &header : source.headers) {
      HashUtils::hash_one(h, header.name);
      HashUtils::hash_one(h, header.value);
    }
  }
  return h;
}

template <typename RegexProps> inline std::string buildLinkRecognitionCacheKey(const RegexProps &props)
{
  std::string key;
  key += props.caseInsensitive ? '1' : '0';
  key += props.dotAll ? '1' : '0';
  key += props.isDisabled ? '1' : '0';
  key += props.isDefault ? '1' : '0';
  return key + props.pattern;
}

// Only EnrichedMarkdown (the segmented host) carries imageSources; the
// EnrichedMarkdownText props hash 0 here. Consumed by ENRMStyleConfigFromProps too.
template <typename PropsType, typename = void> struct ENRMHasImageSources : std::false_type {};
template <typename PropsType>
struct ENRMHasImageSources<PropsType, std::void_t<decltype(std::declval<PropsType>().imageSources)>> : std::true_type {
};

template <typename PropsType> inline size_t ENRMImageSourcesFingerprintForProps(const PropsType &props)
{
  if constexpr (ENRMHasImageSources<PropsType>::value) {
    return computeImageSourcesFingerprint(props.imageSources);
  } else {
    return 0;
  }
}

/// `withMarkdown` false leaves the markdown out: the key then holds everything
/// else that sizes the content, for telling a stream's next update from new content.
template <typename PropsType>
inline MeasurementCacheKey buildMeasurementCacheKey(const PropsType &props, CGFloat maxWidth, CGFloat fontScale,
                                                    MarkdownFlavor flavor, size_t wrappedCodeBlocksFingerprint = 0,
                                                    bool withMarkdown = true)
{
  return MeasurementCacheKey{
      .markdown = withMarkdown ? props.markdown : std::string(),
      .maxWidth = maxWidth,
      .allowTrailingMargin = props.allowTrailingMargin,
      .allowFontScaling = props.allowFontScaling,
      .maxFontSizeMultiplier = props.maxFontSizeMultiplier,
      .md4cFlagsUnderline = props.md4cFlags.underline,
      .md4cFlagsSuperscript = props.md4cFlags.superscript,
      .md4cFlagsSubscript = props.md4cFlags.subscript,
      .md4cFlagsStrikethrough = props.md4cFlags.strikethrough,
      .md4cFlagsHighlight = props.md4cFlags.highlight,
      .md4cFlagsLatexMath = props.md4cFlags.latexMath,
      .md4cFlagsHardSoftBreaks = props.md4cFlags.hardSoftBreaks,
      .md4cFlagsPreserveBlankLines = props.md4cFlags.preserveBlankLines,
      .md4cFlagsAdmonitions = props.md4cFlags.admonitions,
      .styleFingerprint = computeStyleFingerprint(props.markdownStyle),
      .linkPillContentFingerprint = computeLinkPillContentFingerprint(props.linkPillContent),
      .imageSourcesFingerprint = ENRMImageSourcesFingerprintForProps(props),
      .wrappedCodeBlocksFingerprint = wrappedCodeBlocksFingerprint,
      .fontScale = fontScale,
      .flavor = flavor,
      .lineBreakStrategyIOS = props.lineBreakStrategyIOS,
      .writingDirection = props.writingDirection,
      .numberOfLines = props.numberOfLines,
      .ellipsizeMode = props.ellipsizeMode,
      .linkRegexKey = buildLinkRecognitionCacheKey(props.linkRecognition.text),
      .inlineCodeLinkRegexKey = buildLinkRecognitionCacheKey(props.linkRecognition.inlineCode),
  };
}

/**
 * What the previous measurement of a view saw. The next one compares against it
 * to tell a stream's update (the markdown only grew, nothing else changed) from
 * new content.
 */
template <typename PropsT> struct ENRMPreviousMeasurement {
  std::shared_ptr<const PropsT> props;
  /// Everything else that sizes the content (buildMeasurementCacheKey without the markdown).
  std::optional<MeasurementCacheKey> layoutKey;
  /// The writing direction a parent's `direction` resolved to, which the key leaves out.
  int layoutDirection{0};
  /// The state's height counter, which the view advances when it asks for a new height.
  int heightCounter{-1};
  /// What the measurement returned, and for which width.
  CGFloat maxWidth{-1};
  CGFloat width{0};
  CGFloat height{0};
};

/// Whether `current` keeps all of `previous` and only adds to it, as every update
/// of a stream does. Empty `previous` doesn't count: there is nothing laid out to keep.
inline bool ENRMMarkdownExtends(const std::string &previous, const std::string &current)
{
  return !previous.empty() && current.size() >= previous.size() && current.compare(0, previous.size(), previous) == 0;
}

/// Where a measurement's size comes from (ENRMChooseMeasurement).
enum class ENRMMeasurementSource {
  Full,
  Previous,
  LaidOut,
};

/**
 * Picks the source of a measurement.
 *
 * - `streamUpdate`: nothing that sizes the content changed except the markdown,
 *   which kept all of the previous and may have grown.
 * - `grew`: the markdown is longer than last time.
 * - `viewAskedForHeight`: the view laid out a render and asked for a new layout since.
 * - `hasView`: the view is mounted, so it asks again once its height changes.
 * - `hasLaidOutSize`: the view laid its content out for this width.
 * - `samePreviousWidth`: the previous measurement was for this width.
 *
 * The view's size answers a stream's update (it trails by at most the render in
 * flight) and a view that asked again. Otherwise the same document measured again
 * gets the previous answer: Yoga measures twice a pass, and a view sized to its
 * content lays out narrower than offered, so it keeps that size until it asks.
 * Without a view nothing would ask, so a grown document measures in full.
 */
inline ENRMMeasurementSource ENRMChooseMeasurement(bool streamUpdate, bool grew, bool viewAskedForHeight, bool hasView,
                                                   bool hasLaidOutSize, bool samePreviousWidth)
{
  if (!streamUpdate) {
    return ENRMMeasurementSource::Full;
  }
  if (hasLaidOutSize && (grew || viewAskedForHeight)) {
    return ENRMMeasurementSource::LaidOut;
  }
  if (!viewAskedForHeight && samePreviousWidth && (hasView || !grew)) {
    return ENRMMeasurementSource::Previous;
  }
  return ENRMMeasurementSource::Full;
}

/**
 * Thread-safe global measurement cache using an LRU (Least Recently Used) strategy.
 * This ensures O(1) lookups while automatically discarding the oldest entries.
 */
class MeasurementCache {
public:
  struct CacheEntry {
    MeasurementCacheKey key;
    CachedSize size;
  };

  static MeasurementCache &shared()
  {
    static MeasurementCache instance;
    return instance;
  }

  bool get(const MeasurementCacheKey &key, CachedSize &outSize)
  {
    std::lock_guard<std::mutex> lock(mutex_);

    auto it = map_.find(key);
    if (it == map_.end()) {
      return false;
    }

    list_.splice(list_.begin(), list_, it->second);

    outSize = it->second->size;
    return true;
  }

  void set(const MeasurementCacheKey &key, CachedSize size)
  {
    const size_t keyBytes = keyStorageBytes(key);
    if (keyBytes > kMaxKeyBytes)
      return;
    std::lock_guard<std::mutex> lock(mutex_);

    auto it = map_.find(key);
    if (it != map_.end()) {
      it->second->size = size;
      list_.splice(list_.begin(), list_, it->second);
      return;
    }

    while (map_.size() >= kMaxEntries || keyBytes_ + keyBytes > kMaxKeyBytes) {
      auto &lastEntry = list_.back();
      keyBytes_ -= keyStorageBytes(lastEntry.key);
      map_.erase(lastEntry.key);
      list_.pop_back();
    }

    list_.push_front({key, size});
    map_.emplace(std::cref(list_.front().key), list_.begin());
    keyBytes_ += keyBytes;
  }

  void removeMatchingMarkdown(const std::string &markdown)
  {
    std::lock_guard<std::mutex> lock(mutex_);

    for (auto it = list_.begin(); it != list_.end();) {
      if (it->key.markdown == markdown) {
        keyBytes_ -= keyStorageBytes(it->key);
        map_.erase(it->key);
        it = list_.erase(it);
      } else {
        ++it;
      }
    }
  }

private:
  MeasurementCache() = default;

  static constexpr size_t kMaxEntries = 512;
  // Bytes held by keys; allocator/node overhead is additional.
  static constexpr size_t kMaxKeyBytes = 8 * 1024 * 1024;
  static size_t keyStorageBytes(const MeasurementCacheKey &key)
  {
    return sizeof(CacheEntry) + key.markdown.size() + key.lineBreakStrategyIOS.size() + key.writingDirection.size() +
           key.ellipsizeMode.size() + key.linkRegexKey.size() + key.inlineCodeLinkRegexKey.size();
  }

  // The map refers to the key its list node owns, so each key is stored once.
  using KeyRef = std::reference_wrapper<const MeasurementCacheKey>;
  struct KeyRefEqual {
    bool operator()(const MeasurementCacheKey &a, const MeasurementCacheKey &b) const
    {
      return a == b;
    }
  };
  size_t keyBytes_ = 0;
  mutable std::mutex mutex_;

  std::list<CacheEntry> list_;
  std::unordered_map<KeyRef, std::list<CacheEntry>::iterator, MeasurementCacheKeyHash, KeyRefEqual> map_;
};

} // namespace facebook::react
