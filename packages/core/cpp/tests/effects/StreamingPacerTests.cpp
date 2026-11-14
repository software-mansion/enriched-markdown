#include "doctest/doctest.h"

#include "StreamingPacer.hpp"

#include <string>

using Markdown::StreamingPacer;

namespace {
// Appends `chunk` to `text` and tells `pacer` of it.
void append(StreamingPacer &pacer, std::u16string &text, const std::u16string &chunk, double time) {
  size_t start = text.size();
  text += chunk;
  pacer.append(start, chunk, time);
}
} // namespace

TEST_CASE("a chunk's words appear one after another over the time until the next chunk") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"a ", 0.0);
  append(pacer, text, u"one two three four ", 0.5);
  // The four words spread over the half second learnt from the chunks before, the first at once.
  CHECK(pacer.revealed(0.5) == 6);
  CHECK(pacer.revealed(0.5 + 0.13) == 10);
  CHECK(pacer.revealed(0.5 + 0.3) == 16);
  CHECK(pacer.waiting(0.8));
  CHECK(pacer.revealed(0.9) == text.size());
  CHECK_FALSE(pacer.waiting(0.9));
}

TEST_CASE("text is revealed on word boundaries") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"a ", 0.0);
  append(pacer, text, u"alpha beta gamma delta ", 0.3);
  for (double t = 0.3; t < 2; t += 0.01) {
    size_t shown = pacer.revealed(t);
    CHECK((shown == text.size() || text[shown - 1] == u' '));
  }
}

TEST_CASE("a word the chunk ends inside waits for the rest") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"hello wor", 0.0);
  CHECK(pacer.revealed(0.2) == 6);
  append(pacer, text, u"ld ", 0.3);
  CHECK(pacer.revealed(5.0) == text.size());
}

TEST_CASE("a held word shows after waiting half a second") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"hello wor", 0.0);
  CHECK(pacer.waiting(0.3));
  CHECK(pacer.revealed(0.6) == text.size());
  CHECK_FALSE(pacer.waiting(0.6));
  // The rest of it follows.
  append(pacer, text, u"ld and more ", 1.0);
  CHECK(pacer.revealed(1.0) >= 9);
  CHECK(pacer.revealed(5.0) == text.size());
}

TEST_CASE("markdown before a word waits for it") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"intro\n\n", 0.0);
  append(pacer, text, u"## Heading\n- item\n1. first\n> quote ", 0.5);
  for (double t = 0.5; t < 3; t += 0.005) {
    std::u16string shown = text.substr(0, pacer.revealed(t));
    // Never a bare marker at the end.
    for (const char16_t *marker : {u"## ", u"- ", u"1. ", u"> "}) {
      std::u16string m(marker);
      bool endsWithMarker = shown.size() >= m.size() && shown.compare(shown.size() - m.size(), m.size(), m) == 0;
      CHECK_FALSE(endsWithMarker);
    }
  }
}

TEST_CASE("a burst piling up is never more than a second behind") {
  StreamingPacer pacer;
  std::u16string text;
  double time = 0;
  for (int i = 0; i < 30; i++) {
    append(pacer, text, u"w1 w2 w3 w4 w5 w6 w7 w8 w9 w10 ", time);
    time += 0.1;
  }
  CHECK(pacer.revealed(time - 0.1 + 1.0 + 1e-9) == text.size());
}

TEST_CASE("the end of the stream shows what is waiting within 200 ms") {
  StreamingPacer pacer;
  std::u16string text;
  for (int i = 0; i < 5; i++) {
    append(pacer, text, u"word word word word word word word wo", i * 0.8);
  }
  double end = 4 * 0.8 + 0.01;
  CHECK(pacer.revealed(end) < text.size());
  pacer.finish(end);
  CHECK(pacer.revealed(end + 0.2 + 1e-9) == text.size());
  CHECK_FALSE(pacer.waiting(end + 0.2 + 1e-9));
}

TEST_CASE("a text that does not continue the last one shows at once") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"one two three ", 0.0);
  pacer.append(3, u"replaced ", 0.1);
  CHECK(pacer.revealed(0.1) == 12);
  pacer.reset(5);
  CHECK(pacer.revealed(0.2) == 5);
  CHECK_FALSE(pacer.waiting(0.2));
}

TEST_CASE("CJK characters are words of their own") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"a ", 0.0);
  append(pacer, text, u"森林里的树 ", 0.5);
  size_t first = pacer.revealed(0.5);
  CHECK(first > 2);
  CHECK(first < text.size());
}

TEST_CASE("a chunk's last CJK character is not held for the next chunk") {
  StreamingPacer pacer;
  std::u16string text;
  append(pacer, text, u"a ", 0.0);
  append(pacer, text, u"森林", 0.5);
  // Before the half second after which a held word would show anyway.
  CHECK(pacer.revealed(0.95) == text.size());
  CHECK_FALSE(pacer.waiting(0.95));
  // Half of a surrogate pair waits for its other half.
  append(pacer, text, u"\xD840", 1.5);
  CHECK(pacer.revealed(1.6) == text.size() - 1);
  append(pacer, text, u"\xDC00", 1.8);
  CHECK(pacer.revealed(2.1) == text.size());
}

namespace {
// A smooth stream with six words waiting at 1.0, spread over the half second learnt from the
// chunks before; the stream's end shows them by 1.2.
const std::u16string kWaiting = u"a b one two three four five six ";
void streamWithWordsWaiting(StreamingPacer &pacer) {
  pacer.update(u"a ", true, true, 0.0);
  pacer.update(u"a b ", true, true, 0.5);
  pacer.update(kWaiting, true, true, 1.0);
}
} // namespace

TEST_CASE("the end of the stream waits for the drain, and ends it once") {
  StreamingPacer pacer;
  streamWithWordsWaiting(pacer);
  CHECK(pacer.waiting(1.0));
  CHECK_FALSE(pacer.update(kWaiting, false, true, 1.0));
  CHECK_FALSE(pacer.drained(1.1));
  CHECK(pacer.drained(1.2));
  CHECK(pacer.revealed(1.2) == kWaiting.size());
  CHECK_FALSE(pacer.drained(1.3));
  CHECK_FALSE(pacer.update(kWaiting, false, true, 1.4));
}

TEST_CASE("the end of the stream with nothing waiting ends it at once") {
  StreamingPacer pacer;
  pacer.update(u"a ", true, true, 0.0);
  CHECK(pacer.update(u"a ", false, true, 1.0));
  CHECK_FALSE(pacer.drained(1.0));
  // Without smooth pacing too, the last text showing at once.
  CHECK_FALSE(pacer.update(u"a b ", true, false, 2.0));
  CHECK(pacer.update(u"a b c d ", false, false, 2.0));
  CHECK(pacer.revealed(2.0) == 8);
}

TEST_CASE("streaming again cancels the drain") {
  StreamingPacer pacer;
  streamWithWordsWaiting(pacer);
  pacer.update(kWaiting, false, true, 1.0);
  CHECK_FALSE(pacer.update(kWaiting + u"seven ", true, true, 1.1));
  for (double t = 1.1; t < 3; t += 0.05) {
    CHECK_FALSE(pacer.drained(t));
  }
}

// The hosts end the draining stream themselves when a new one starts: the drain must not end it
// again.
TEST_CASE("a new stream during the drain cancels it") {
  StreamingPacer pacer;
  streamWithWordsWaiting(pacer);
  pacer.update(kWaiting, false, true, 1.0);
  CHECK_FALSE(pacer.update(u"next ", true, true, 1.05));
  for (double t = 1.05; t < 3; t += 0.05) {
    CHECK_FALSE(pacer.drained(t));
  }
}

TEST_CASE("a text replaced during the drain shows at once and ends the stream") {
  StreamingPacer pacer;
  streamWithWordsWaiting(pacer);
  pacer.update(kWaiting, false, true, 1.0);
  CHECK(pacer.update(u"another text", false, true, 1.05));
  CHECK(pacer.revealed(1.05) == 12);
  CHECK_FALSE(pacer.drained(1.5));
}

TEST_CASE("smooth turned off during the drain shows all at once and ends the stream") {
  StreamingPacer pacer;
  streamWithWordsWaiting(pacer);
  pacer.update(kWaiting, false, true, 1.0);
  CHECK(pacer.update(kWaiting, false, false, 1.05));
  CHECK(pacer.revealed(1.05) == kWaiting.size());
  CHECK_FALSE(pacer.drained(1.5));
}

TEST_CASE("text arriving after the end of the stream drains with the rest") {
  StreamingPacer pacer;
  streamWithWordsWaiting(pacer);
  pacer.update(kWaiting, false, true, 1.0);
  std::u16string text = kWaiting + u"seven eight nine ten ";
  CHECK_FALSE(pacer.update(text, false, true, 1.1));
  CHECK(pacer.revealed(1.15) < text.size());
  CHECK_FALSE(pacer.drained(1.15));
  CHECK(pacer.drained(1.3));
  CHECK(pacer.revealed(1.3) == text.size());
}

TEST_CASE("the first text and a text that does not continue the last show at once") {
  StreamingPacer pacer;
  pacer.update(u"one two three four five six ", true, true, 0.0);
  CHECK(pacer.revealed(0.0) == 28);
  pacer.update(u"other words that do not continue ", true, true, 0.5);
  CHECK(pacer.revealed(0.5) == 33);
  // Without the prop, nothing is paced.
  StreamingPacer stillPacer;
  stillPacer.update(u"a ", false, true, 0.0);
  stillPacer.update(u"a b ", false, true, 0.5);
  CHECK_FALSE(stillPacer.update(kWaiting, false, true, 1.0));
  CHECK(stillPacer.revealed(1.0) == kWaiting.size());
}
