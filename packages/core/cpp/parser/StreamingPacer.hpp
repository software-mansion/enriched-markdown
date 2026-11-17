#pragma once
#include <cstddef>
#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace Markdown {

// Paces streamed text word by word. Each chunk spreads over the time until the next one, at most a
// second behind; a word the chunk ends inside waits for the rest. When the stream ends, what is
// waiting drains first. Lengths are UTF-16 code units; times are seconds on any monotonic clock.
class StreamingPacer {
public:
  // With `smooth`, while streaming or draining, text that continues the last one is paced; any other
  // shows at once. `streaming` turning off starts the drain (finish), turning on cancels it. Returns
  // whether the stream ends now: nothing was waiting, or the drain finished or was cut short.
  bool update(std::u16string_view text, bool streaming, bool smooth, double time);
  // Whether the drain finished by `time`: true once, and the stream ends then.
  bool drained(double time);

  // The text grew from `start` (its length so far) by `added` at `time`.
  void append(size_t start, std::u16string_view added, double time);
  // Shows `length` characters at once and forgets what was waiting: pacing off, or a text that
  // replaced the one before.
  void reset(size_t length);
  // The stream ended at `time`: what is waiting appears quickly.
  void finish(double time);

  // How many characters to show at `time`.
  size_t revealed(double time) const;
  // Whether more is revealed after `time`.
  bool waiting(double time) const;

private:
  // Show the text up to `end` from `time` on.
  struct Step {
    size_t end;
    double time;
  };

  void schedule(double from, double until);

  std::vector<Step> steps_;
  // What every step before `steps_` revealed.
  size_t shown_ = 0;
  size_t length_ = 0;
  // The characters after the last step: a word the last chunk ended inside, with any markdown
  // before it (`-`, `##`) that waits for a word, held back since `tailSince_`.
  std::u16string tail_;
  std::optional<double> tailSince_;
  // Whether the tail starts a line: a line that is a table row (`|` first) is hidden until it ends,
  // so it is one step, not one a word.
  bool lineStart_ = true;
  std::optional<double> lastArrival_;
  // The usual time between chunks, which each chunk spreads over.
  std::optional<double> arrivalGap_;
  // What update was last given.
  std::u16string text_;
  bool streaming_ = false;
  // The prop turned off and what was waiting is still to appear.
  bool draining_ = false;
};

} // namespace Markdown
