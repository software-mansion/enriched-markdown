#include "StreamingPacer.hpp"
#include "StreamingWords.hpp"

#include <algorithm>
#include <limits>

namespace Markdown {

namespace {

// A chunk spreads over the time until the next one, at most this long; the text falls at most
// this far behind; a held word shows after this long without the rest; what is waiting when the
// stream ends shows within this long.
constexpr double kMaxSpread = 1.0;
constexpr double kMaxLag = 1.0;
constexpr double kTailHold = 0.5;
constexpr double kDrain = 0.2;
// The first chunk, with no gap to learn from yet, spreads over this long.
constexpr double kFirstSpread = 0.05;
constexpr double kNever = std::numeric_limits<double>::infinity();

// Whether a word is only markdown waiting for the word after it: a list marker (`-`, `1.`), a
// heading's `##`, a quote's `>`, emphasis opening before a space.
bool waitsForNextWord(std::u16string_view word) {
  size_t end = word.size();
  while (end > 0 && isStreamingSpace(word[end - 1])) {
    end--;
  }
  bool hasDigit = false;
  for (size_t i = 0; i < end; i++) {
    char16_t c = word[i];
    if (c >= 0x80 || (c >= u'a' && c <= u'z') || (c >= u'A' && c <= u'Z')) {
      return false;
    }
    hasDigit = hasDigit || (c >= u'0' && c <= u'9');
  }
  if (!hasDigit) {
    return true;
  }
  // Digits are a word unless they mark an ordered list item.
  for (size_t i = 0; i + 1 < end; i++) {
    if (word[i] < u'0' || word[i] > u'9') {
      return false;
    }
  }
  return end > 1 && (word[end - 1] == u'.' || word[end - 1] == u')');
}

} // namespace

void StreamingPacer::append(size_t start, std::u16string_view added, double time) {
  if (start != length_) {
    reset(start + added.size());
    return;
  }
  if (added.empty()) {
    return;
  }
  if (lastArrival_) {
    double gap = std::clamp(time - *lastArrival_, 0.0, kMaxSpread);
    arrivalGap_ = arrivalGap_ ? *arrivalGap_ * 0.7 + gap * 0.3 : gap;
  }
  lastArrival_ = time;
  // Steps that have passed, and a held word shown after waiting too long, count as shown.
  auto passed = std::find_if(steps_.begin(), steps_.end(), [&](const Step &step) { return step.time > time; });
  if (passed != steps_.begin()) {
    shown_ = std::prev(passed)->end;
    steps_.erase(steps_.begin(), passed);
  }
  if (steps_.empty() && !tail_.empty() && tailSince_ && time - *tailSince_ >= kTailHold) {
    shown_ = length_;
    tail_.clear();
  }
  size_t base = length_ - tail_.size();
  std::u16string text = tail_ + std::u16string(added);
  length_ = start + added.size();
  double lastWaiting = steps_.empty() ? time : steps_.back().time;
  size_t stepped = 0;
  for (size_t i = 0; i < text.size();) {
    size_t next = wordEnd(text, i);
    bool complete = next < text.size() || isStreamingSpace(text.back());
    if (!complete) {
      break;
    }
    if (!waitsForNextWord(std::u16string_view(text).substr(i, next - i))) {
      steps_.push_back({base + next, kNever});
      stepped = next;
    }
    i = next;
  }
  bool hadTail = !tail_.empty();
  tail_ = text.substr(stepped);
  if (tail_.empty()) {
    tailSince_.reset();
  } else if (!hadTail || stepped > 0) {
    tailSince_ = time;
  }
  schedule(time, std::min(std::max(time + arrivalGap_.value_or(kFirstSpread), lastWaiting), time + kMaxLag));
}

// Spreads the steps still waiting evenly from `from` to `until`, the first one at once.
void StreamingPacer::schedule(double from, double until) {
  auto waiting = std::find_if(steps_.begin(), steps_.end(), [&](const Step &step) { return step.time > from; });
  size_t count = static_cast<size_t>(steps_.end() - waiting);
  for (size_t i = 0; waiting != steps_.end(); ++waiting, ++i) {
    waiting->time = from + (until - from) * static_cast<double>(i) / static_cast<double>(count);
  }
}

void StreamingPacer::reset(size_t length) {
  steps_.clear();
  shown_ = length;
  length_ = length;
  tail_.clear();
  tailSince_.reset();
  lastArrival_.reset();
  arrivalGap_.reset();
}

void StreamingPacer::finish(double time) {
  double lastWaiting = !steps_.empty() && steps_.back().time > time ? steps_.back().time : time;
  if (!tail_.empty()) {
    steps_.push_back({length_, kNever});
    tail_.clear();
    tailSince_.reset();
  }
  schedule(time, std::min(lastWaiting, time + kDrain));
}

size_t StreamingPacer::revealed(double time) const {
  size_t shown = shown_;
  for (const Step &step : steps_) {
    if (step.time > time) {
      return shown;
    }
    shown = step.end;
  }
  if (!tail_.empty() && tailSince_ && time - *tailSince_ >= kTailHold) {
    return length_;
  }
  return shown;
}

bool StreamingPacer::waiting(double time) const {
  if (!steps_.empty() && steps_.back().time > time) {
    return true;
  }
  return !tail_.empty() && tailSince_ && time - *tailSince_ < kTailHold;
}

} // namespace Markdown
