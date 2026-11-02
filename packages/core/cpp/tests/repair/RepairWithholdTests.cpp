#include <string>

#include "RepairInternal.hpp"
#include "doctest/doctest.h"

using namespace Markdown;

namespace {

RepairOptions withholding() {
  RepairOptions o;
  o.withholdIncomplete = true;
  return o;
}

RepairOptions withholdingMath() {
  RepairOptions o = withholding();
  o.withholdMath = true;
  o.inlineMath = true;
  return o;
}

std::string repair(std::string_view s, const RepairOptions &o = withholding()) {
  return repairInlineMarkdown(s, o);
}

} // namespace

TEST_CASE("withhold: a delimiter with nothing after it waits") {
  CHECK(repair("Hello **") == "Hello");
  CHECK(repair("Hello *") == "Hello");
  CHECK(repair("Hello `") == "Hello");
  CHECK(repair("Hello ||") == "Hello");
  CHECK(repair("Hello ==") == "Hello");
  CHECK(repair("**") == "");
  CHECK(repair("Para\n\n**") == "Para\n\n");
  CHECK(repair("a * b") == "a * b");
  CHECK(repair("**bold **") == "**bold**");
  CHECK(repair("`a` **") == "`a`");
  CHECK(repair("`co **") == "`co **`");
  CHECK(repair("Press `*`") == "Press `*`");
  CHECK(repair("use `=`") == "use `=`");
  CHECK(repair("Op `||`") == "Op `||`");
  CHECK(repair("| a |\n|---|\n| `|` |") == "| a |\n|---|\n| `|` |");
  CHECK(repair("x =") == "x =");
  CHECK(repair("Hello\xC2\xA0**") == "Hello");
  CHECK(repair("```\ncode\n```") == "```\ncode\n```");
  CHECK(repair("~~~\ncode\n~~~") == "~~~\ncode\n~~~");
  CHECK(repair("Hello **", RepairOptions()) == "Hello **");
}

TEST_CASE("withhold: a last line that is only a block marker") {
  CHECK(repair("Paragraph\n-") == "Paragraph\n");
  CHECK(repair("Paragraph\n--") == "Paragraph\n");
  CHECK(repair("Paragraph\n=") == "Paragraph\n");
  CHECK(repair("Paragraph\n---") == "Paragraph\n---");
  CHECK(repair("Intro\n\n***\n") == "Intro\n\n***\n");
  CHECK(repair("Intro\n\n___\n") == "Intro\n\n___\n");
  CHECK(repair("Intro\n\n* * *\n") == "Intro\n\n* * *\n");
  CHECK(repair("Intro\n\n***") == "Intro\n\n");
  CHECK(repair("Intro\n\n#") == "Intro\n\n");
  CHECK(repair("Intro\n\n## ") == "Intro\n\n");
  CHECK(repair("Intro\n\n#hashtag") == "Intro\n\n#hashtag");
  CHECK(repair("Intro\n\n``") == "Intro\n\n");
  CHECK(repair("- one\n- ") == "- one\n");
  CHECK(repair("- one\n* ") == "- one\n");
  CHECK(repair("1. one\n2.") == "1. one\n");
  CHECK(repair("-") == "");
  CHECK(repair("- **") == "");
  CHECK(repair("## **") == "");
  CHECK(repair("> quote\n>") == "> quote\n");
  CHECK(repair("> quote\n> ") == "> quote\n");
  CHECK(repair("| a |\n|") == "| a |\n");
  CHECK(repair("| a |\n| b |") == "| a |\n| b |");
  CHECK(repair("Price\n12") == "Price\n12");
  CHECK(repair("-foo") == "-foo");
  CHECK(repair("Paragraph\n-", RepairOptions()) == std::string("Paragraph\n-").append(RepairInternal::kZeroWidthSpace));
}

TEST_CASE("withhold: admonition titles and task checkboxes still being typed") {
  CHECK(repair("Intro\n\n> [!") == "Intro\n\n");
  CHECK(repair("Intro\n\n> [!NO") == "Intro\n\n");
  CHECK(repair("Intro\n\n> [!NOTE]") == "Intro\n\n> [!NOTE]");
  CHECK(repair("Intro\n\n> [!NOTE]\n> Body **b") == "Intro\n\n> [!NOTE]\n> Body **b**");
  CHECK(repair("See [!important") == "See [!important](streamdown:incomplete-link)");
  CHECK(repair("- [x] done\n- [") == "- [x] done\n");
  CHECK(repair("- [x] done\n- [x") == "- [x] done\n");
  CHECK(repair("- [x] done\n- [ ") == "- [x] done\n");
  CHECK(repair("- [ ]") == "- [ ]");
  CHECK(repair("- [x]") == "- [x]");
  CHECK(repair("- [x] **done") == "- [x] **done**");
  CHECK(repair("- [L") == "- [L](streamdown:incomplete-link)");
}

TEST_CASE("withhold: a closing fence still being typed") {
  const std::string open = "Intro\n\n```swift\nlet x = **y\n";
  CHECK(repair(open) == open);
  CHECK(repair(open + "``") == open);
  CHECK(repair(open + "`") == open);
  CHECK(repair("> ```\n> code\n> ``") == "> ```\n> code\n");
  CHECK(repair("```\ncode **x") == "```\ncode **x");
  CHECK(repair("````\ncode\n```") == "````\ncode\n");
  CHECK(repair("````\ncode\n````") == "````\ncode\n````");
}

TEST_CASE("a marker line inside an open fence is code") {
  CHECK(repair("```\ncode\n-") == "```\ncode\n-");
  CHECK(repair("```\ncode\n-", RepairOptions()) == "```\ncode\n-");
  CHECK(repair("```\ncode\n=", RepairOptions()) == "```\ncode\n=");
}

TEST_CASE("withhold: an image label without a source") {
  CHECK(repair("Text ![alt]") == "Text");
  CHECK(repair("- ![alt]") == "");
  CHECK(repair("`![alt]`") == "`![alt]`");
  CHECK(repair("Text \\![alt]") == "Text \\![alt]");
  CHECK(repair("![a]\n\nmore ![b]") == "![a]\n\nmore");
  CHECK(repair("See [docs]") == "See [docs]");
}

TEST_CASE("withhold: unclosed math is cut at its opener") {
  const RepairOptions o = withholdingMath();
  CHECK(repair("The area is $\\pi r^", o) == "The area is");
  CHECK(repair("Closed $x^2$ and open $\\frac{1}", o) == "Closed $x^2$ and open");
  CHECK(repair("$a $b", o) == "$a");
  CHECK(repair("Prices in $USD or $EUR today", o) == "Prices in $USD or");
  CHECK(repair("Display $$\\sum_i", o) == "Display");
  CHECK(repair("$$\nx^2 +\n", o) == "");
  CHECK(repair("Intro\n\n$$\nx^2 +", o) == "Intro\n\n");
  CHECK(repair("Done: $a_1$.", o) == "Done: $a_1$.");
  CHECK(repair("Earlier $x in a finished paragraph\n\nNext **b", o) ==
        "Earlier $x in a finished paragraph\n\nNext **b**");
  CHECK(repair("| $x | y", o) == "| $x | y");
  CHECK(repair("| $x", o) == "");
  CHECK(repair("# Cost in $USD\nSome text", o) == "# Cost in $USD\nSome text");
  CHECK(repair("# Cost in $USD\n", o) == "# Cost in $USD\n");
  CHECK(repair("See \xC2\xAB$x", o) == "See \xC2\xAB");
}

TEST_CASE("withhold: a dollar next to a digit or space is currency") {
  const RepairOptions o = withholdingMath();
  CHECK(repair("Das kostet 5$ und mehr", o) == "Das kostet 5$ und mehr");
  CHECK(repair("Das kostet 5 $ pro Stück", o) == "Das kostet 5 $ pro Stück");
  CHECK(repair("It costs $5 and", o) == "It costs $5 and");
  CHECK(repair("Für 3$ bekommst du **viel", o) == "Für 3$ bekommst du **viel**");
  CHECK(repair("It costs $5 and **more", o) == "It costs $5 and **more**");
  RepairOptions closing;
  closing.inlineMath = true;
  CHECK(repair("It costs $5 and", closing) == "It costs $5 and$");
  CHECK(repair("It costs $5 and **more", closing) == "It costs $5 and **more$");
}

TEST_CASE("withhold: the handlers read dollars the way the parser does") {
  const RepairOptions o = withholdingMath();
  CHECK(repair("Let $a_1 + b_2$ be _small", o) == "Let $a_1 + b_2$ be _small_");
  CHECK(repair("$\\sum_{i=1}^n x_i$ and _y", o) == "$\\sum_{i=1}^n x_i$ and _y_");
  CHECK(repair("`$HOME` and **b", o) == "`$HOME` and **b**");
  CHECK(repair("```\n$ npm i\n```\n**b", o) == "```\n$ npm i\n```\n**b**");
  CHECK(repair("Open $x stays open **b", o) == "Open");
  CHECK(repair("$a $$b$$ _c", o) == "$a $$b$$ _c_");
  RepairOptions parserOnly;
  parserOnly.inlineMath = true;
  parserOnly.withholdMath = true;
  CHECK(repair("# Cost $USD\nsome _it", parserOnly) == "# Cost $USD\nsome _it_");
}

TEST_CASE("withhold: math follows the math options") {
  RepairOptions o = withholding();
  o.withholdMath = true;
  CHECK(repair("The area is $\\pi r^", o) == "The area is $\\pi r^");
  CHECK(repair("Display $$\\sum_i", o) == "Display");
  o.displayMath = false;
  CHECK(repair("Display $$\\sum_i", o) == "Display $$\\sum_i");
}

TEST_CASE("closers go before trailing whitespace") {
  CHECK(repair("**bold  ", RepairOptions()) == "**bold**  ");
  CHECK(repair("*italic  \n", RepairOptions()) == "*italic*  \n");
  CHECK(repair("**bold\t", RepairOptions()) == "**bold**\t");
  CHECK(repair("**bold\r\n", RepairOptions()) == "**bold**\r\n");
}
