// fixtures/input/known-limitations.json: behavior of the TypeScript reference
// that the port reproduces on purpose and that the fuzz tests work around. A
// case failing here means a limitation was fixed (update the file) or a
// regression was introduced.
#include "FixtureFile.hpp"
#include "TestSupport.hpp"
#include "doctest/doctest.h"
#include <map>

using namespace TestSupport;
using FixtureFile::Json;

namespace {

std::string utf8(const std::u16string &s) {
  return Markdown::toUtf8(s);
}

const Json &required(const Json &object, const std::string &key) {
  const Json *found = FixtureFile::member(object, key);
  REQUIRE_MESSAGE(found != nullptr, "missing " << key);
  return *found;
}

uint32_t number(const Json &json) {
  return static_cast<uint32_t>(std::stoul(utf8(json.string)));
}

StyleType styleType(const std::string &name) {
  static const std::map<std::string, StyleType> types = {
      {"strong", StyleType::Strong},       {"em", StyleType::Em},
      {"underline", StyleType::Underline}, {"strikethrough", StyleType::Strikethrough},
      {"link", StyleType::Link},           {"spoiler", StyleType::Spoiler}};
  return types.at(name);
}

BlockType blockType(const std::string &name) {
  static const std::map<std::string, BlockType> types = {{"p", BlockType::Paragraph},
                                                         {"h1", BlockType::H1},
                                                         {"h2", BlockType::H2},
                                                         {"h3", BlockType::H3},
                                                         {"h4", BlockType::H4},
                                                         {"h5", BlockType::H5},
                                                         {"h6", BlockType::H6},
                                                         {"ul", BlockType::UnorderedListItem},
                                                         {"ol", BlockType::OrderedListItem}};
  return types.at(name);
}

} // namespace

TEST_CASE("known limitations of the reference") {
  const Json root = FixtureFile::read("known-limitations.json");
  size_t checked = 0;
  for (const Json &fixture : required(root, "cases").items) {
    const std::string kind = utf8(required(fixture, "kind").string);
    const std::string description = utf8(required(fixture, "description").string);
    INFO(description);
    if (kind == "chain") {
      std::u16string markdown = required(fixture, "markdown").string;
      INFO("markdown: " << show(markdown));
      const auto &trips = required(fixture, "trips").items;
      for (const Json &expected : trips) {
        markdown = roundTrip(markdown);
        CHECK(show(markdown) == show(expected.string));
      }
      // Settled after the listed trips.
      CHECK(show(roundTrip(markdown)) == show(markdown));
    } else {
      REQUIRE(kind == "model");
      const std::u16string &text = required(fixture, "text").string;
      std::vector<FormattingRange> ranges;
      for (const Json &r : required(fixture, "ranges").items) {
        FormattingRange range;
        range.type = styleType(utf8(r.items[0].string));
        range.start = number(r.items[1]);
        range.end = number(r.items[2]);
        range.url = r.items.size() > 3 ? r.items[3].string : std::u16string();
        ranges.push_back(range);
      }
      std::vector<BlockRange> blocks;
      for (const Json &b : required(fixture, "blocks").items) {
        BlockRange block;
        block.type = blockType(utf8(b.items[0].string));
        block.start = number(b.items[1]);
        block.end = number(b.items[2]);
        block.level = static_cast<uint8_t>(number(b.items[3]));
        blocks.push_back(block);
      }
      const std::u16string markdown = serialize(text, ranges, blocks);
      CHECK(show(markdown) == show(required(fixture, "markdown").string));
      const ParseResult parsed = parse(markdown);
      CHECK(show(parsed.plainText) == show(required(fixture, "parsedText").string));
      if (const Json *links = FixtureFile::member(fixture, "parsedLinks")) {
        REQUIRE(parsed.formattingRanges.size() == links->items.size());
        for (size_t i = 0; i < links->items.size(); i++) {
          CHECK(show(parsed.formattingRanges[i].url) == show(links->items[i].string));
        }
      }
      if (const Json *count = FixtureFile::member(fixture, "parsedBlocks")) {
        CHECK(parsed.blockRanges.size() == number(*count));
      }
    }
    checked++;
  }
  CHECK(checked == 8);
}
