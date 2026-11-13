#include "doctest/doctest.h"

#include "StreamingEffects.hpp"

#include <string>

using Markdown::CharacterLook;
using Markdown::EffectColor;
using Markdown::StreamingEffectConfig;
using Markdown::StreamingEffects;
using Markdown::StreamingEffectType;

namespace {
StreamingEffects effects(StreamingEffectConfig config) {
  StreamingEffects result;
  result.configure(config);
  return result;
}

StreamingEffectConfig fade() {
  StreamingEffectConfig config;
  config.type = StreamingEffectType::Fade;
  config.duration = 0.2;
  return config;
}

StreamingEffectConfig gradient(size_t length) {
  StreamingEffectConfig config;
  config.type = StreamingEffectType::Gradient;
  config.length = length;
  return config;
}

StreamingEffectConfig none() {
  StreamingEffectConfig config;
  config.type = StreamingEffectType::None;
  return config;
}

// Appends `chunk` to `text` and tells `fx` of it.
void append(StreamingEffects &fx, std::u16string &text, const std::u16string &chunk, double time) {
  size_t start = text.size();
  char16_t previous = start > 0 ? text[start - 1] : u' ';
  text += chunk;
  fx.noteArrival(start, text.size(), time, chunk, previous);
}
} // namespace

TEST_CASE("a fade takes each word from transparent to opaque over its duration") {
  auto fx = effects(fade());
  std::u16string text;
  append(fx, text, u"one two ", 1.0);
  CHECK(fx.lookAt(5, 1.0).opacity == doctest::Approx(0));
  CHECK(fx.lookAt(5, 1.1).opacity == doctest::Approx(0.75));
  CHECK(fx.lookAt(5, 1.2).opacity == doctest::Approx(1));
  CHECK(fx.lookAt(5, 1.1).tintAmount == 0);
}

TEST_CASE("chunks a frame apart fade on their own") {
  auto fx = effects(fade());
  std::u16string text;
  append(fx, text, u"aaaaaaaaa ", 1.0);
  append(fx, text, u"bbbbbbbbb ", 1.016);
  // The first chunk keeps fading instead of snapping when the second arrives.
  CHECK(fx.lookAt(5, 1.05).opacity == doctest::Approx(0.4375));
  CHECK(fx.lookAt(15, 1.05).opacity < fx.lookAt(5, 1.05).opacity);
  auto range = fx.animatedRange(1.05);
  REQUIRE(range);
  CHECK(range->start == 0);
  CHECK(range->length == 20);
}

TEST_CASE("a word split across chunks fades as one") {
  auto fx = effects(fade());
  std::u16string text;
  append(fx, text, u"hel", 1.0);
  append(fx, text, u"lo world", 1.1);
  // "lo" keeps the time "hel" arrived at; "world" has its own.
  CHECK(fx.lookAt(3, 1.1).opacity == doctest::Approx(fx.lookAt(0, 1.1).opacity));
  CHECK(fx.lookAt(6, 1.1).opacity == doctest::Approx(0));
}

TEST_CASE("the rest of a word that has appeared shows at once") {
  auto fx = effects(fade());
  std::u16string text;
  append(fx, text, u"hel", 1.0);
  append(fx, text, u"lo", 2.0);
  CHECK(fx.lookAt(3, 2.0).opacity == 1);
}

TEST_CASE("a look ends where the characters after it look different") {
  auto fx = effects(fade());
  std::u16string text = u"settled ";
  fx.noteArrival(0, text.size(), 0.0, text);
  append(fx, text, u"one two ", 1.0);
  append(fx, text, u"three", 1.1);
  // Pruned at 1.0: "settled " shows as it is, up to the first fading word.
  CHECK(fx.animatedRange(1.0)->start == 8);
  CHECK(fx.lookEnd(0) == 8);
  // A chunk's words fade together.
  CHECK(fx.lookEnd(8) == 16);
  CHECK(fx.lookEnd(12) == 16);
  CHECK(fx.lookEnd(16) == 21);
  CHECK(fx.lookEnd(21) == 22);
  // Every character up to a look's end looks the same, whatever the time.
  for (double time : {1.0, 1.05, 1.15, 1.25}) {
    for (size_t i = 0; i < text.size(); i++) {
      for (size_t j = i; j < fx.lookEnd(i); j++) {
        CHECK(fx.lookAt(j, time).opacity == fx.lookAt(i, time).opacity);
      }
    }
  }
  auto gradientFx = effects(gradient(4));
  std::u16string gradientText;
  append(gradientFx, gradientText, u"abcdef", 1.0);
  CHECK(gradientFx.lookEnd(3) == 4);
}

TEST_CASE("a fade stops changing once every word has appeared") {
  auto fx = effects(fade());
  std::u16string text;
  append(fx, text, u"one two", 1.0);
  CHECK(fx.changesOverTime(1.1));
  CHECK_FALSE(fx.changesOverTime(1.25));
  CHECK_FALSE(fx.animatedRange(1.25));
  CHECK(fx.lookAt(5, 1.25).opacity == 1);
}

TEST_CASE("a gradient fades the last characters by their distance from the end") {
  auto fx = effects(gradient(4));
  std::u16string text;
  append(fx, text, u"0123456789", 1.0);
  auto range = fx.animatedRange(5.0);
  REQUIRE(range);
  CHECK(range->start == 6);
  CHECK(range->length == 4);
  CHECK(fx.lookAt(9, 5.0).opacity == doctest::Approx(0));
  CHECK(fx.lookAt(8, 5.0).opacity == doctest::Approx(0.25));
  CHECK(fx.lookAt(6, 5.0).opacity == doctest::Approx(0.75));
  CHECK(fx.lookAt(5, 5.0).opacity == doctest::Approx(1));
  // It follows the text, not the clock.
  CHECK_FALSE(fx.changesOverTime(5.0));
}

TEST_CASE("a gradient settles to the characters' own colors after the stream ends") {
  auto fx = effects(gradient(4));
  std::u16string text;
  append(fx, text, u"0123456789", 1.0);
  fx.finish(2.0);
  fx.finish(2.1);
  CHECK(fx.changesOverTime(2.1));
  CHECK(fx.lookAt(9, 2.1).opacity == doctest::Approx(0.75));
  CHECK_FALSE(fx.animatedRange(2.2));
  CHECK_FALSE(fx.changesOverTime(2.2));
  // A render that adds nothing keeps it settled.
  fx.noteArrival(10, 10, 2.5, u"", u'9');
  CHECK_FALSE(fx.animatedRange(2.5));
  // New text streams again.
  append(fx, text, u"ab", 3.0);
  CHECK(fx.animatedRange(3.0));
}

TEST_CASE("a gradient between two colors replaces the characters' own color") {
  auto config = gradient(4);
  config.startColor = EffectColor{0, 0, 1, 1};
  config.endColor = EffectColor{0, 0, 0, 0};
  auto fx = effects(config);
  std::u16string text;
  append(fx, text, u"0123456789", 1.0);
  CharacterLook oldest = fx.lookAt(6, 5.0);
  CHECK(oldest.tintAmount == 1);
  CHECK(oldest.tint.b == doctest::Approx(1));
  CHECK(oldest.tint.a == doctest::Approx(0.75));
  CharacterLook newest = fx.lookAt(9, 5.0);
  // A transparent end keeps the start's hue.
  CHECK(newest.tint.b == doctest::Approx(1));
  CHECK(newest.tint.a == doctest::Approx(0));
}

TEST_CASE("a gradient to an opaque color tints the newest characters") {
  auto config = gradient(4);
  config.endColor = EffectColor{1, 0, 0, 1};
  auto fx = effects(config);
  std::u16string text;
  append(fx, text, u"0123456789", 1.0);
  CHECK(fx.lookAt(9, 5.0).tintAmount == doctest::Approx(1));
  CHECK(fx.lookAt(6, 5.0).tintAmount == doctest::Approx(0.25));
  CHECK(fx.lookAt(5, 5.0).tintAmount == doctest::Approx(0));
  CHECK(fx.lookAt(9, 5.0).opacity == 1);
}

TEST_CASE("a gradient from a color to an opaque color runs between the two") {
  auto config = gradient(4);
  config.startColor = EffectColor{0, 0, 1, 1};
  config.endColor = EffectColor{1, 0, 0, 1};
  auto fx = effects(config);
  fx.noteArrival(0, 10, 1.0, u"abcdefghij");
  CharacterLook newest = fx.lookAt(9, 5.0);
  CHECK(newest.tintAmount == 1);
  CHECK(newest.tint.r == doctest::Approx(1));
  CHECK(newest.tint.b == doctest::Approx(0));
  CHECK(newest.tint.a == doctest::Approx(1));
  CharacterLook oldest = fx.lookAt(6, 5.0);
  CHECK(oldest.tint.r == doctest::Approx(0.25));
  CHECK(oldest.tint.b == doctest::Approx(0.75));
  CHECK(fx.lookAt(5, 5.0).tint.b == doctest::Approx(1));
}

TEST_CASE("a tinted gradient settles to the characters' own colors") {
  auto config = gradient(4);
  config.endColor = EffectColor{1, 0, 0, 1};
  auto fx = effects(config);
  fx.noteArrival(0, 10, 1.0, u"abcdefghij");
  fx.finish(2.0);
  CHECK(fx.lookAt(9, 2.1).tintAmount == doctest::Approx(0.25));
  CHECK(fx.lookAt(9, 2.2).tintAmount == doctest::Approx(0));
  CHECK_FALSE(fx.animatedRange(2.2));
}

TEST_CASE("configuring starts over") {
  auto fx = effects(fade());
  fx.noteArrival(0, 10, 1.0, u"abcdefghij");
  fx.configure(gradient(4));
  // Nothing arrived since: no text to follow.
  CHECK_FALSE(fx.animatedRange(1.0));
  fx.noteArrival(10, 12, 1.1, u"kl");
  auto range = fx.animatedRange(1.1);
  REQUIRE(range);
  CHECK(range->start == 8);
  CHECK(range->length == 4);
  // A finished stream streams again once configured.
  fx.finish(1.2);
  fx.configure(gradient(4));
  fx.noteArrival(0, 12, 5.0, u"abcdefghijkl");
  CHECK(fx.lookAt(11, 5.0).opacity == doctest::Approx(0));
}

TEST_CASE("a fade over no time or a gradient over no characters is no effect") {
  auto config = fade();
  config.duration = 0;
  auto fx = effects(config);
  CHECK(fx.config().type == StreamingEffectType::None);
  fx.noteArrival(0, 10, 1.0, u"abcdefghij");
  CHECK_FALSE(fx.animatedRange(1.0));
  CHECK(fx.lookAt(5, 1.0).opacity == 1);
  fx.configure(gradient(0));
  CHECK(fx.config().type == StreamingEffectType::None);
}

TEST_CASE("no effect animates nothing") {
  auto fx = effects(none());
  std::u16string text;
  append(fx, text, u"one two", 1.0);
  CHECK_FALSE(fx.animatedRange(1.0));
  CHECK(fx.lookAt(5, 1.0).opacity == 1);
}

TEST_CASE("text that shrinks drops the words past its end") {
  auto fx = effects(fade());
  std::u16string text;
  append(fx, text, u"one two three", 1.0);
  fx.noteArrival(13, 4, 1.05, u"", u' ');
  auto range = fx.animatedRange(1.05);
  REQUIRE(range);
  CHECK(range->start + range->length == 4);
}
