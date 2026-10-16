#include "md4c.h"
#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

struct Result {
  std::vector<std::string> links;
  std::string text;
};
static int block(MD_BLOCKTYPE, void *, void *) {
  return 0;
}
static int enterSpan(MD_SPANTYPE type, void *detail, void *data) {
  if (type == MD_SPAN_A) {
    const auto &href = static_cast<MD_SPAN_A_DETAIL *>(detail)->href;
    static_cast<Result *>(data)->links.emplace_back(href.text, href.size);
  }
  return 0;
}
static int leaveSpan(MD_SPANTYPE, void *, void *) {
  return 0;
}
static int text(MD_TEXTTYPE, const MD_CHAR *value, MD_SIZE size, void *data) {
  static_cast<Result *>(data)->text.append(value, size);
  return 0;
}
static void check(const std::string &source, const std::vector<std::string> &links,
                  unsigned flags = MD_DIALECT_GITHUB) {
  MD_PARSER parser = {};
  parser.flags = flags;
  parser.enter_block = block;
  parser.leave_block = block;
  parser.enter_span = enterSpan;
  parser.leave_span = leaveSpan;
  parser.text = text;
  Result result;
  if (md_parse(source.data(), source.size(), &parser, &result) != 0 || result.links != links) {
    std::cerr << "Unexpected autolinks for: " << source << '\n';
    for (const auto &link : result.links)
      std::cerr << "  actual: " << link << '\n';
    std::exit(1);
  }
}
int main() {
  check("http://localhost:3000", {"http://localhost:3000"});
  check("https://devbox/path", {"https://devbox/path"});
  check("http://127.0.0.1:8081/index.bundle?platform=ios&dev=true",
        {"http://127.0.0.1:8081/index.bundle?platform=ios&dev=true"});
  check("https://example.com:8443/a%20b?q=x+y&other=a:b#part-1",
        {"https://example.com:8443/a%20b?q=x+y&other=a:b#part-1"});
  check("See http://localhost:3000/path.", {"http://localhost:3000/path"});
  check("(http://localhost:3000/path)", {"http://localhost:3000/path"});
  check("https://example.com/a(b)c", {"https://example.com/a(b)c"});
  check("https://example.com/?q=a%20b,c!&next=x+y", {"https://example.com/?q=a%20b,c!&next=x+y"});
  check("https://example.com/#part:1%20two", {"https://example.com/#part:1%20two"});
  check("http://localhost:3000?query=yes", {"http://localhost:3000?query=yes"});
  check("http://localhost:3000#section", {"http://localhost:3000#section"});
  check("http://localhost:3000 https://example.com/path", {"http://localhost:3000", "https://example.com/path"});
  check("[local](http://localhost:3000)", {"http://localhost:3000"});
  check("`http://localhost:3000`", {});
  check("www.example.com/path", {"http://www.example.com/path"});
  check("www.localhost", {});
  check("a@example.com", {"mailto:a@example.com"});
  check("http://localhost:3000", {}, MD_DIALECT_COMMONMARK);
  check("<http://localhost:3000>", {"http://localhost:3000"}, MD_DIALECT_COMMONMARK);
  std::cout << "19 production MD4C autolink cases passed\n";
}
