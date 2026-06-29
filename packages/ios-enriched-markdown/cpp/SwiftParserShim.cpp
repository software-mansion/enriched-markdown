#include "SwiftParserCAPI.h"

#include "MD4CParser.hpp"

#include <memory>
#include <new>
#include <string>

static_assert(static_cast<int>(Markdown::NodeType::Highlight) == 29,
              "NodeType enum must stay in sync with Swift NodeType");

struct EMCParseResult {
  std::shared_ptr<Markdown::MarkdownASTNode> root;
};

struct EMASTAttributeIterator {
  std::unordered_map<std::string, std::string>::const_iterator current;
  std::unordered_map<std::string, std::string>::const_iterator end;
};

namespace {

const Markdown::MarkdownASTNode *asNode(const void *node) {
  return static_cast<const Markdown::MarkdownASTNode *>(node);
}

} // namespace

extern "C" {

EMCParseResult *em_parse_markdown(const char *markdown, int underline, int latexMath, int superscript, int subscript,
                                  int highlight, int permissiveAutolinks) {
  auto *result = new (std::nothrow) EMCParseResult();
  if (!result) {
    return nullptr;
  }

  Markdown::Md4cFlags flags;
  flags.underline = underline != 0;
  flags.latexMath = latexMath != 0;
  flags.superscript = superscript != 0;
  flags.subscript = subscript != 0;
  flags.highlight = highlight != 0;
  flags.permissiveAutolinks = permissiveAutolinks != 0;

  Markdown::MD4CParser parser;
  result->root = parser.parse(markdown ? std::string(markdown) : "", flags);
  return result;
}

void em_parse_result_release(EMCParseResult *result) {
  delete result;
}

const void *em_ast_root(const EMCParseResult *result) {
  if (!result || !result->root) {
    return nullptr;
  }
  return result->root.get();
}

int em_ast_node_type(const void *node) {
  if (!node) {
    return 0;
  }
  return static_cast<int>(asNode(node)->type);
}

const char *em_ast_node_content(const void *node) {
  if (!node) {
    return "";
  }
  return asNode(node)->content.c_str();
}

size_t em_ast_node_child_count(const void *node) {
  if (!node) {
    return 0;
  }
  return asNode(node)->children.size();
}

const void *em_ast_node_child_at(const void *node, size_t index) {
  if (!node) {
    return nullptr;
  }

  const auto &children = asNode(node)->children;
  if (index >= children.size() || !children[index]) {
    return nullptr;
  }
  return children[index].get();
}

EMASTAttributeIterator *em_ast_node_attribute_iterator_create(const void *node) {
  if (!node) {
    return nullptr;
  }

  const auto &attributes = asNode(node)->attributes;
  if (attributes.empty()) {
    return nullptr;
  }

  auto *iterator = new (std::nothrow) EMASTAttributeIterator{attributes.cbegin(), attributes.cend()};
  return iterator;
}

int em_ast_node_attribute_iterator_next(EMASTAttributeIterator *iterator, const char **key, const char **value) {
  if (!iterator || iterator->current == iterator->end) {
    return 0;
  }

  if (key) {
    *key = iterator->current->first.c_str();
  }
  if (value) {
    *value = iterator->current->second.c_str();
  }
  ++iterator->current;
  return 1;
}

void em_ast_node_attribute_iterator_release(EMASTAttributeIterator *iterator) {
  delete iterator;
}

} // extern "C"
