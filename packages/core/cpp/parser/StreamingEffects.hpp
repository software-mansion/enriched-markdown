#pragma once
#include <cstddef>
#include <optional>
#include <string_view>
#include <vector>

namespace Markdown {

enum class StreamingEffectType { None, Fade, Gradient };

struct EffectColor {
  float r = 0, g = 0, b = 0, a = 0;
};

struct StreamingEffectConfig {
  StreamingEffectType type = StreamingEffectType::Fade;
  // Fade: how long a word takes to appear, in seconds.
  double duration = 0.2;
  // Gradient: how many characters from the end it covers.
  size_t length = 20;
  // Gradient: the colors at its start (older characters) and its end (the newest). Unset keeps
  // each character's own color: full at the start, transparent at the end.
  std::optional<EffectColor> startColor;
  std::optional<EffectColor> endColor;
};

// How to draw one character: its own color moved `tintAmount` of the way to `tint`, then its
// opacity multiplied by `opacity`.
struct CharacterLook {
  EffectColor tint;
  float tintAmount = 0;
  float opacity = 1;
};

struct CharacterRange {
  size_t start = 0;
  size_t length = 0;
};

// The look of a streaming text's newest characters: from the time their word arrived (fade) or
// their distance from the end of the text (gradient). Hosts draw the characters with it and never
// change the text. Indices and lengths are UTF-16 code units; times are seconds on any monotonic
// clock.
class StreamingEffects {
public:
  // Starts over. A fade over no time, or a gradient over no characters, is None.
  void configure(const StreamingEffectConfig &config);
  const StreamingEffectConfig &config() const {
    return config_;
  }

  // The text grew from `start` to `end` at `time`; `text` holds those characters and `previous`
  // the one before them (a word they continue keeps its own time).
  void noteArrival(size_t start, size_t end, double time, std::u16string_view text, char16_t previous = u' ');
  // The stream ended at `time`, or the text it animates is finished: what still animates settles.
  // Later calls keep the first time; new text streams again, after what settled.
  void finish(double time);
  void reset();

  // Whether the looks change from frame to frame: a fade, a gradient gliding to new text, or a
  // gradient settling.
  bool changesOverTime(double time);
  // The characters drawn differently at `time`; empty when none.
  std::optional<CharacterRange> animatedRange(double time);
  CharacterLook lookAt(size_t index, double time) const;
  // Where the look of the character at `index` ends: the characters before it look the same at any
  // time (a chunk's words, or the text between them). Past `index`.
  size_t lookEnd(size_t index) const;

private:
  // A word (with the spaces after it) fading in from when it arrived.
  struct Unit {
    size_t start;
    size_t end;
    double time;
  };

  void prune(double time);
  const Unit *unitAt(size_t index) const;
  // Where the gradient ends at `time`: it follows the end of the text at a steady speed instead of
  // jumping to it.
  double gradientEnd(double time) const;

  StreamingEffectConfig config_;
  std::vector<Unit> units_;
  size_t textLength_ = 0;
  // The gradient's end: at `glideFrom_` at `glideStart_`, moving at `glideSpeed_` characters a second
  // toward the end of the text. `growthGap_` is the usual time between growths.
  double glideFrom_ = 0;
  double glideStart_ = 0;
  double glideSpeed_ = 0;
  double growthGap_ = 0;
  std::optional<double> lastGrowth_;
  std::optional<double> finishedAt_;
  // The characters before it settled when the text stopped streaming and stay as they are: text
  // arriving later fades in on its own.
  size_t settledEnd_ = 0;
  // When those characters began settling, and where their gradient ended then: they finish it
  // while new text streams after them. Characters before `settledFloor_` settled earlier.
  std::optional<double> settledAt_;
  double settledGradientEnd_ = 0;
  size_t settledFloor_ = 0;
  bool settling(double time) const;
};

} // namespace Markdown
