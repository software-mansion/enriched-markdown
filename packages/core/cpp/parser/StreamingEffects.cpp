#include "StreamingEffects.hpp"

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

void StreamingEffects::noteArrival(size_t start, size_t end, double time) {
  textLength_ = end;
  if (end <= start) {
    return;
  }
  finishedAt_.reset();
  if (config_.type != StreamingEffectType::Fade) {
    return;
  }
  prune(time);
  arrivals_.push_back({start, end, time});
}

void StreamingEffects::finish(double time) {
  if (!finishedAt_) {
    finishedAt_ = time;
  }
}

void StreamingEffects::reset() {
  arrivals_.clear();
  textLength_ = 0;
  finishedAt_.reset();
}

void StreamingEffects::prune(double time) {
  auto settled = std::find_if(arrivals_.begin(), arrivals_.end(),
                              [&](const Arrival &arrival) { return time - arrival.time < config_.duration; });
  arrivals_.erase(arrivals_.begin(), settled);
}

bool StreamingEffects::changesOverTime(double time) {
  if (config_.type == StreamingEffectType::Gradient) {
    return finishedAt_ && time - *finishedAt_ < kSettleDuration;
  }
  return animatedRange(time).has_value();
}

std::optional<CharacterRange> StreamingEffects::animatedRange(double time) {
  switch (config_.type) {
    case StreamingEffectType::Gradient: {
      if (textLength_ == 0 || (finishedAt_ && time - *finishedAt_ >= kSettleDuration)) {
        return std::nullopt;
      }
      size_t start = textLength_ > config_.length ? textLength_ - config_.length : 0;
      return CharacterRange{start, textLength_ - start};
    }
    case StreamingEffectType::Fade: {
      prune(time);
      if (arrivals_.empty()) {
        return std::nullopt;
      }
      size_t start = arrivals_.front().start;
      size_t end = arrivals_.front().end;
      for (const auto &arrival : arrivals_) {
        start = std::min(start, arrival.start);
        end = std::max(end, arrival.end);
      }
      return CharacterRange{start, end - start};
    }
    case StreamingEffectType::None:
      return std::nullopt;
  }
  return std::nullopt;
}

CharacterLook StreamingEffects::lookAt(size_t index, double time) const {
  CharacterLook look;
  if (config_.type == StreamingEffectType::Fade) {
    for (auto it = arrivals_.rbegin(); it != arrivals_.rend(); ++it) {
      if (index >= it->start && index < it->end) {
        look.opacity = easeOut((time - it->time) / config_.duration);
        break;
      }
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
