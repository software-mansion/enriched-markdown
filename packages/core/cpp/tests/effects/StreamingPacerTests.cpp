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
