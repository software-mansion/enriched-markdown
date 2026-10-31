#pragma once

#include "MarkdownASTNode.hpp"
#include <memory>
#include <string>

namespace Markdown {

struct Md4cFlags {
  bool underline = false;
  bool latexMath = true;
  bool superscript = false;
  bool subscript = false;
  bool strikethrough = false;
  bool highlight = false;
  bool permissiveAutolinks = true;
  bool hardSoftBreaks = false;
  bool preserveBlankLines = false;
  bool admonitions = true;

  bool operator==(const Md4cFlags &other) const {
    return underline == other.underline && latexMath == other.latexMath && superscript == other.superscript &&
           subscript == other.subscript && strikethrough == other.strikethrough && highlight == other.highlight &&
           permissiveAutolinks == other.permissiveAutolinks && hardSoftBreaks == other.hardSoftBreaks &&
           preserveBlankLines == other.preserveBlankLines && admonitions == other.admonitions;
  }
};

class MD4CParser {
public:
  MD4CParser();
  ~MD4CParser();

  // Parse markdown string and return AST root node
  std::shared_ptr<MarkdownASTNode> parse(const std::string &markdown, const Md4cFlags &flags = Md4cFlags{},
                                         bool isGFM = true);

private:
  class Impl;
  std::unique_ptr<Impl> impl_;
};

} // namespace Markdown
