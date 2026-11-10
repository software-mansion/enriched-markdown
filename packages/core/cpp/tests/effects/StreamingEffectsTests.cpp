#include "doctest/doctest.h"

#include "StreamingEffects.hpp"

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
} // namespace

TEST_CASE("a fade takes each chunk from transparent to opaque over its duration") {
  auto fx = effects(fade());
  fx.noteArrival(0, 10, 1.0);
  CHECK(fx.lookAt(5, 1.0).opacity == doctest::Approx(0));
  CHECK(fx.lookAt(5, 1.1).opacity == doctest::Approx(0.75));
  CHECK(fx.lookAt(5, 1.2).opacity == doctest::Approx(1));
  CHECK(fx.lookAt(5, 1.1).tintAmount == 0);
}

TEST_CASE("chunks a frame apart fade on their own") {
  auto fx = effects(fade());
  fx.noteArrival(0, 10, 1.0);
  fx.noteArrival(10, 20, 1.016);
  // The first chunk keeps fading instead of snapping when the second arrives.
  CHECK(fx.lookAt(5, 1.05).opacity == doctest::Approx(0.4375));
  CHECK(fx.lookAt(15, 1.05).opacity < fx.lookAt(5, 1.05).opacity);
  auto range = fx.animatedRange(1.05);
  REQUIRE(range);
  CHECK(range->start == 0);
  CHECK(range->length == 20);
}

TEST_CASE("a fade stops changing once every chunk has appeared") {
  auto fx = effects(fade());
  fx.noteArrival(0, 10, 1.0);
  CHECK(fx.changesOverTime(1.1));
  CHECK_FALSE(fx.changesOverTime(1.25));
  CHECK_FALSE(fx.animatedRange(1.25));
  CHECK(fx.lookAt(5, 1.25).opacity == 1);
}

TEST_CASE("a gradient fades the last characters by their distance from the end") {
  auto fx = effects(gradient(4));
  fx.noteArrival(0, 10, 1.0);
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
  fx.noteArrival(0, 10, 1.0);
  fx.finish(2.0);
  fx.finish(2.1);
  CHECK(fx.changesOverTime(2.1));
  CHECK(fx.lookAt(9, 2.1).opacity == doctest::Approx(0.75));
  CHECK_FALSE(fx.animatedRange(2.2));
  CHECK_FALSE(fx.changesOverTime(2.2));
  // A render that adds nothing keeps it settled.
  fx.noteArrival(10, 10, 2.5);
  CHECK_FALSE(fx.animatedRange(2.5));
  // New text streams again.
  fx.noteArrival(10, 12, 3.0);
  CHECK(fx.animatedRange(3.0));
}

TEST_CASE("a gradient between two colors replaces the characters' own color") {
  auto config = gradient(4);
  config.startColor = EffectColor{0, 0, 1, 1};
  config.endColor = EffectColor{0, 0, 0, 0};
  auto fx = effects(config);
  fx.noteArrival(0, 10, 1.0);
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
  fx.noteArrival(0, 10, 1.0);
  CHECK(fx.lookAt(9, 5.0).tintAmount == doctest::Approx(1));
  CHECK(fx.lookAt(6, 5.0).tintAmount == doctest::Approx(0.25));
  CHECK(fx.lookAt(5, 5.0).tintAmount == doctest::Approx(0));
  CHECK(fx.lookAt(9, 5.0).opacity == 1);
}

TEST_CASE("no effect animates nothing") {
  StreamingEffectConfig config;
  config.type = StreamingEffectType::None;
  auto fx = effects(config);
  fx.noteArrival(0, 10, 1.0);
  CHECK_FALSE(fx.animatedRange(1.0));
  CHECK(fx.lookAt(5, 1.0).opacity == 1);
}
