/*
 * Dumps the serialized AST of each input file, under every flag variant, so a
 * change in the vendored parser or in MD4CParser shows up as a golden diff.
 * See scripts/test-core-parser.sh.
 */
#include "ASTSerializer.hpp"
#include "MD4CParser.hpp"
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::string basename(const std::string &path) {
  const auto slash = path.find_last_of('/');
  return slash == std::string::npos ? path : path.substr(slash + 1);
}

Markdown::Md4cFlags allDisabled() {
  Markdown::Md4cFlags flags{};
  flags.latexMath = false;
  flags.permissiveAutolinks = false;
  flags.admonitions = false;
  return flags;
}

Markdown::Md4cFlags allEnabled() {
  Markdown::Md4cFlags flags{};
  flags.underline = true;
  flags.latexMath = true;
  flags.superscript = true;
  flags.subscript = true;
  flags.highlight = true;
  flags.permissiveAutolinks = true;
  flags.hardSoftBreaks = true;
  flags.preserveBlankLines = true;
  flags.admonitions = true;
  return flags;
}

struct Variant {
  const char *name;
  Markdown::Md4cFlags flags;
  bool isGFM;
};

} // namespace

int main(int argc, char **argv) {
  const std::vector<Variant> variants = {
      {"defaults-gfm", Markdown::Md4cFlags{}, true},     {"defaults-commonmark", Markdown::Md4cFlags{}, false},
      {"extensions-off-gfm", allDisabled(), true},       {"extensions-on-gfm", allEnabled(), true},
      {"extensions-on-commonmark", allEnabled(), false},
  };

  Markdown::MD4CParser parser;
  for (int i = 1; i < argc; i++) {
    std::ifstream file(argv[i], std::ios::binary);
    if (!file) {
      std::cerr << "cannot open " << argv[i] << "\n";
      return 2;
    }
    std::stringstream buffer;
    buffer << file.rdbuf();
    const std::string markdown = buffer.str();

    for (const Variant &variant : variants) {
      const auto root = parser.parse(markdown, variant.flags, variant.isGFM);
      std::cout << "=== " << basename(argv[i]) << " [" << variant.name << "] ===\n"
                << (root ? Markdown::ASTSerializer::serialize(*root) : std::string("<null>")) << "\n";
    }
  }
  return 0;
}
