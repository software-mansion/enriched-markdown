#include "StreamingEffects.hpp"
#include "StreamingWords.hpp"

#include <algorithm>

namespace Markdown {

namespace {

// The gradient settles to the characters' own colors this long after the stream ends.
constexpr double kSettleDuration = 0.2;

float easeOut(double progress) {
  double clamped = std::clamp(progress, 0.0, 1.0);
  return static_cast<float>(1.0 - (1.0 - clamped) * (1.0 - clamped));
}

EffectColor mix(const EffectColor &from, const EffectColor &to, float amount) {
  return {from.r + (to.r - from.r) * amount, from.g + (to.g - from.g) * amount, from.b + (to.b - from.b) * amount,
          from.a + (to.a - from.a) * amount};
}

// A transparent end keeps the hue of the color it fades from.
EffectColor transparentLike(const EffectColor &color) {
  return {color.r, color.g, color.b, 0};
}

} // namespace

void StreamingEffects::configure(const StreamingEffectConfig &config) {
  config_ = config;
  reset();
}

void StreamingEffects::noteArrival(size_t start, size_t end, double time, std::u16string_view text, char16_t previous) {
  if (end < textLength_) {
    units_.erase(std::remove_if(units_.begin(), units_.end(), [&](const Unit &unit) { return unit.start >= end; }),
                 units_.end());
    if (!units_.empty()) {
      units_.back().end = std::min(units_.back().end, end);
    }
  }
  textLength_ = end;
  if (end <= start) {
    return;
  }
  finishedAt_.reset();
  if (config_.type != StreamingEffectType::Fade) {
    return;
  }
  prune(time);
  if (text.size() != end - start) {
    units_.push_back({start, end, time});
    return;
  }
  size_t i = 0;
  // Spaces, or the rest of a word the last chunk ended inside, go with that word; when it has
  // already appeared, they show at once.
  bool continues =
      isStreamingSpace(text[0]) || (!isStreamingSpace(previous) && !isOwnWord(previous) && !isOwnWord(text[0]));
  if (continues) {
    if (isStreamingSpace(text[0])) {
      while (i < text.size() && isStreamingSpace(text[i])) {
        i++;
      }
    } else {
      i = wordEnd(text, 0);
    }
    if (!units_.empty() && units_.back().end == start) {
      units_.back().end = start + i;
    }
  }
  while (i < text.size()) {
    size_t next = wordEnd(text, i);
    units_.push_back({start + i, start + next, time});
    i = next;
  }
}

void StreamingEffects::finish(double time) {
  if (!finishedAt_) {
    finishedAt_ = time;
  }
}

void StreamingEffects::reset() {
  units_.clear();
  textLength_ = 0;
  finishedAt_.reset();
}

void StreamingEffects::prune(double time) {
  auto settled =
      std::find_if(units_.begin(), units_.end(), [&](const Unit &unit) { return time - unit.time < config_.duration; });
  units_.erase(units_.begin(), settled);
}

const StreamingEffects::Unit *StreamingEffects::unitAt(size_t index) const {
  auto after =
      std::upper_bound(units_.begin(), units_.end(), index, [](size_t i, const Unit &unit) { return i < unit.start; });
  if (after == units_.begin()) {
    return nullptr;
  }
  const Unit &unit = *std::prev(after);
  return index < unit.end ? &unit : nullptr;
}

bool StreamingEffects::changesOverTime(double time) {
  if (config_.type == StreamingEffectType::Gradient) {
    return finishedAt_ && time - *finishedAt_ < kSettleDuration;
  }
  return animatedRange(time).has_value();
}

std::optional<CharacterRange> StreamingEffects::animatedRange(double time) {
  if (textLength_ == 0) {
    return std::nullopt;
  }
  switch (config_.type) {
    case StreamingEffectType::Gradient: {
      if (finishedAt_ && time - *finishedAt_ >= kSettleDuration) {
        return std::nullopt;
      }
      size_t start = textLength_ > config_.length ? textLength_ - config_.length : 0;
      return CharacterRange{start, textLength_ - start};
    }
    case StreamingEffectType::Fade: {
      prune(time);
      if (units_.empty()) {
        return std::nullopt;
      }
      size_t start = std::min(units_.front().start, textLength_);
      return CharacterRange{start, std::min(units_.back().end, textLength_) - start};
    }
    case StreamingEffectType::None:
      return std::nullopt;
  }
  return std::nullopt;
}

CharacterLook StreamingEffects::lookAt(size_t index, double time) const {
  CharacterLook look;
  if (config_.type == StreamingEffectType::Fade) {
    if (const Unit *unit = unitAt(index)) {
      look.opacity = easeOut((time - unit->time) / config_.duration);
    }
    return look;
  }
  if (config_.type != StreamingEffectType::Gradient) {
    return look;
  }
  // 0 for the newest character, 1 for the first one past the gradient.
  size_t fromEnd = textLength_ > index ? textLength_ - 1 - index : 0;
  float position =
      std::min(1.0f, static_cast<float>(fromEnd) / static_cast<float>(std::max<size_t>(config_.length, 1)));
  const auto &start = config_.startColor;
  const auto &end = config_.endColor;
  if (start) {
    // One color for the whole tail, the character's own color left behind.
    EffectColor to = end ? (end->a == 0 ? transparentLike(*start) : *end) : transparentLike(*start);
    look.tint = mix(to, *start, position);
    look.tintAmount = 1;
  } else if (end && end->a > 0) {
    look.tint = *end;
    look.tintAmount = 1 - position;
  } else {
    look.opacity = position;
  }
  if (finishedAt_) {
    float settle = easeOut((time - *finishedAt_) / kSettleDuration);
    look.tintAmount *= 1 - settle;
    look.opacity += (1 - look.opacity) * settle;
  }
  return look;
}

} // namespace Markdown
