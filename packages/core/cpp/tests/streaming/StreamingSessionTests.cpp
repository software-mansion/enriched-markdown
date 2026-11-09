#include <string>
#include <string_view>

#include "StreamingSession.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {

StreamingSessionOptions hostOptions() {
  StreamingSessionOptions options;
  options.repair.linkMode = LinkMode::TextOnly;
  options.repair.withholdIncomplete = true;
  options.repair.withholdMath = true;
  return options;
}

StreamingFilterOptions hidingCodeBlocks() {
  StreamingFilterOptions options;
  options.codeBlockMode = StreamingBlockMode::Hidden;
  return options;
}

std::string finished(const StreamingUpdate &update, std::string_view markdown) {
  return std::string(markdown.substr(update.frozenBytes, update.finishedBytes));
}

StreamingUpdate once(std::string_view markdown) {
  StreamingSession session(hostOptions());
  return session.update(markdown, {});
}

} // namespace

TEST_CASE("session: a block after a blank line finishes the text before it") {
  StreamingSession session(hostOptions());
  std::string_view markdown = "# Title\n\nFirst paragraph.\n\nSecond";
  StreamingUpdate update = session.update(markdown, {});
  CHECK(update.frozenBytes == 0);
  CHECK(finished(update, markdown) == "# Title\n\nFirst paragraph.\n\n");
  CHECK(update.tail == "Second");
  CHECK_FALSE(update.finishedContinuedByTail);

  markdown = "# Title\n\nFirst paragraph.\n\nSecond with **bold";
  update = session.update(markdown, {});
  CHECK(update.frozenBytes == 27);
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "Second with **bold**");
}

TEST_CASE("session: no cut without a blank line, before a continuation or inside a fence") {
  CHECK(once("Line one\nLine two").finishedBytes == 0);
  CHECK(once("- one\n\n  continued").finishedBytes == 0);
  CHECK(once("Para\n\n    indented code").finishedBytes == 0);
  CHECK(once("```\ncode\n\nmore code").finishedBytes == 0);
  CHECK(once("Para\n- one").finishedBytes == 0);
  CHECK(finished(once("```\ncode\n\nmore\n```\n\nAfter"), "```\ncode\n\nmore\n```\n\nAfter") ==
        "```\ncode\n\nmore\n```\n\n");
}

TEST_CASE("session: raw HTML and HTML blocks hide the cuts inside them") {
  CHECK(finished(once("A\n\nB\n\n<!-- note\n\nC"), "A\n\nB\n\n<!-- note\n\nC") == "A\n\n");
  CHECK(once("- one\n<div>\n- two\n- three").finishedBytes == 0);
  StreamingUpdate update = once("- one\n<div>\n- two\n\n- three");
  CHECK(update.tail == "- three");
  CHECK_FALSE(update.tailContinuesList);
}

TEST_CASE("session: nothing finishes while the tail is withheld") {
  StreamingUpdate update = once("Para\n\n- ");
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "Para\n\n");
  update = once("- one\n- two\n- [");
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "- one\n- two\n");
}

TEST_CASE("session: list items finish one by one and the list goes on") {
  StreamingSession session(hostOptions());
  std::string_view markdown = "Intro\n\n- one\n- two\n- three";
  StreamingUpdate update = session.update(markdown, {});
  CHECK(finished(update, markdown) == "Intro\n\n- one\n- two\n");
  CHECK_FALSE(update.finishedContinuesList);
  CHECK(update.finishedContinuedByTail);
  CHECK(update.tail == "- three");
  CHECK(update.tailContinuesList);

  markdown = "Intro\n\n- one\n- two\n- three\n- four";
  update = session.update(markdown, {});
  CHECK(finished(update, markdown) == "- three\n");
  CHECK(update.finishedContinuesList);
  CHECK(update.finishedContinuedByTail);
  CHECK(update.tail == "- four");
  CHECK(update.tailContinuesList);

  markdown = "Intro\n\n- one\n- two\n- three\n- four\n\nAfter";
  update = session.update(markdown, {});
  CHECK(finished(update, markdown) == "- four\n\n");
  CHECK(update.finishedContinuesList);
  CHECK_FALSE(update.finishedContinuedByTail);
  CHECK(update.tail == "After");
  CHECK_FALSE(update.tailContinuesList);
}

TEST_CASE("session: items of another list, a loose list and a lazy line") {
  CHECK(once("- one\n* two").finishedBytes == 0);
  StreamingUpdate update = once("- one\n\n* two");
  CHECK(update.tail == "* two");
  CHECK_FALSE(update.tailContinuesList);
  update = once("- one\n\n- two");
  CHECK(update.tail == "- two");
  CHECK(update.tailContinuesList);
  CHECK(once("- one\nlazy\n- two").tail == "- two");
  CHECK(once("1. one\n1) two").finishedBytes == 0);
  CHECK(once("* one\n* * *").finishedBytes == 0);
  CHECK(once("- [x] one\n- [ ] two").tail == "- [ ] two");
  CHECK(once("1. one\n2. two\n3. three").tail == "3. three");
}

TEST_CASE("session: restarting the open list forgets its finished items") {
  StreamingSession session(hostOptions());
  std::string_view markdown = "Intro\n\n1. a\n2. b\n3. c";
  StreamingUpdate update = session.update(markdown, {});
  CHECK(finished(update, markdown) == "Intro\n\n1. a\n2. b\n");

  markdown = "Intro\n\n1. a\n2. b\n3. c\n4. d";
  update = session.update(markdown, {});
  CHECK(update.frozenBytes == 17);
  update = session.restartOpenList(markdown, {});
  CHECK(update.frozenBytes == 0);
  CHECK(finished(update, markdown) == "Intro\n\n");
  CHECK(update.tail == "1. a\n2. b\n3. c\n4. d");
  CHECK_FALSE(update.tailContinuesList);

  markdown = "Intro\n\n1. a\n2. b\n3. c\n4. d\n5. e";
  update = session.update(markdown, {});
  CHECK(update.frozenBytes == 7);
  CHECK(finished(update, markdown) == "1. a\n2. b\n3. c\n4. d\n");
  CHECK_FALSE(update.finishedContinuesList);
  CHECK(update.finishedContinuedByTail);
  CHECK(update.tail == "5. e");
}

TEST_CASE("session: markdown that does not extend the frozen text starts a new lineage") {
  StreamingSession session(hostOptions());
  StreamingUpdate first = session.update("First answer.\n\nSecond paragraph", {});
  CHECK(first.finishedBytes == 15);
  StreamingUpdate second = session.update("A different answer", {});
  CHECK(second.lineage != first.lineage);
  CHECK(second.frozenBytes == 0);
  CHECK(second.tail == "A different answer");
}

TEST_CASE("session: a link reference definition renders the whole document") {
  StreamingSession session(hostOptions());
  StreamingUpdate update = session.update("See [x].\n\nMore", {});
  CHECK(update.finishedBytes == 10);
  update = session.update("See [x].\n\nMore\n\n[x]: https://example.com", {});
  CHECK(update.frozenBytes == 0);
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "See [x].\n\nMore\n\n[x]: https://example.com");
  update = session.update("See [x].\n\nMore\n\n[x]: https://example.com\n\nEnd", {});
  CHECK(update.frozenBytes == 0);
  CHECK(update.finishedBytes == 0);
}

TEST_CASE("session: the whole document is the tail when blocks are not cut") {
  StreamingSessionOptions options = hostOptions();
  options.cutBlocks = false;
  StreamingSession session(options);
  StreamingUpdate update = session.update("# Title\n\nPara\n\nMore", {});
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "# Title\n\nPara\n\nMore");
}

TEST_CASE("session: an open fence keeps its body out of the parse") {
  std::string_view markdown = "Intro\n\n```swift\nlet x = **y\n``";
  StreamingUpdate update = once(markdown);
  CHECK(finished(update, markdown) == "Intro\n\n");
  CHECK(update.tail == "```swift\nlet x = **y\n");
  CHECK(update.tailEndsInsideOpenCodeFence);
  CHECK(update.tailCodeBodyStart == 9);

  update = once("Intro\n\n```swift\nlet x\n```  ");
  CHECK(update.tail == "```swift\nlet x\n```  ");
  update = once("Intro\n\n````swift\nlet x\n```");
  CHECK(update.tail == "````swift\nlet x\n");
  update = once("Intro\n\n```swift");
  CHECK(update.tailCodeBodyStart == std::string::npos);
}

TEST_CASE("session: a fence with no code yet finishes nothing") {
  StreamingUpdate update = once("Para\n\n```p");
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "Para\n\n```p");
  CHECK(update.tailEndsInsideOpenCodeFence);
  update = once("Para\n\n```python\n");
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "Para\n\n```python\n");
  update = once("Para\n\n```python\nx");
  CHECK(update.finishedBytes == 6);
  CHECK(update.tail == "```python\nx");
}

TEST_CASE("session: a fence inside a list item or a quote is repaired like any tail") {
  StreamingUpdate update = once("- item\n\n  ```swift\n  let x = 1");
  CHECK(update.tailEndsInsideOpenCodeFence);
  CHECK(update.tailCodeBodyStart == std::string::npos);
  CHECK(update.tail == "- item\n\n  ```swift\n  let x = 1");
}

TEST_CASE("session: a hidden open fence is not in the tail") {
  StreamingSession session(hostOptions());
  StreamingUpdate update = session.update("Intro\n\n```swift\nlet x = 1\n", hidingCodeBlocks());
  CHECK(update.finishedBytes == 0);
  CHECK(update.tail == "Intro\n\n");
  CHECK_FALSE(update.tailEndsInsideOpenCodeFence);
  update = session.update("Intro\n\n```swift\nlet x = 1\n```\n", hidingCodeBlocks());
  CHECK(update.tail == "```swift\nlet x = 1\n```\n");
  CHECK(update.frozenBytes == 0);
  CHECK(update.finishedBytes == 7);
}

TEST_CASE("session: the tail is filtered and repaired with the host's rules") {
  StreamingUpdate update = once("Intro\n\n| A | B |\n|---|---|\n| 1 | 2 |\n| 3 |");
  CHECK(update.tail == "| A | B |\n|---|---|\n| 1 | 2 |\n");
  update = once("See [docs](https://e");
  CHECK(update.tail == "See");
  update = once("Text with *ital");
  CHECK(update.tail == "Text with *ital*");
}
