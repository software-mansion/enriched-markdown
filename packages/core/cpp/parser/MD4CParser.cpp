#include "MD4CParser.hpp"
#include "../md4c/md4c.h"
#include <cstring>
#include <vector>

namespace Markdown {

class MD4CParser::Impl {
public:
  std::shared_ptr<MarkdownASTNode> root;
  std::vector<std::shared_ptr<MarkdownASTNode>> nodeStack;
  std::string currentText;
  const char *inputText = nullptr;

  static const std::string ATTR_LEVEL;
  static const std::string ATTR_URL;
  static const std::string ATTR_TITLE;
  static const std::string ATTR_FENCE_CHAR;
  static const std::string ATTR_LANGUAGE;
  static const std::string ATTR_IS_TASK;
  static const std::string ATTR_TASK_CHECKED;
  static const std::string ATTR_START;

  void reset(size_t estimatedDepth) {
    root = std::make_shared<MarkdownASTNode>(NodeType::Document);
    nodeStack.clear();
    // Reserve based on estimated depth, with reasonable bounds
    // Typical markdown has 5-15 levels, but can go deeper with nested structures
    // Cap at 128 to avoid excessive memory for extreme cases
    nodeStack.reserve(std::min(estimatedDepth, static_cast<size_t>(128)));
    nodeStack.push_back(root);
    currentText.clear();
    currentText.reserve(256);
  }

  void flushText() {
    if (!currentText.empty() && !nodeStack.empty()) {
      auto textNode = std::make_shared<MarkdownASTNode>(NodeType::Text);
      textNode->content = std::move(currentText);
      nodeStack.back()->addChild(std::move(textNode));
      currentText.clear();
    }
  }

  void pushNode(std::shared_ptr<MarkdownASTNode> node) {
    flushText();
    if (node && !nodeStack.empty()) {
      nodeStack.back()->addChild(node);
      nodeStack.push_back(std::move(node));
    }
  }

  void popNode() {
    flushText();
    if (nodeStack.size() > 1) {
      nodeStack.pop_back();
    }
  }

  void addInlineNode(std::shared_ptr<MarkdownASTNode> node) {
    flushText();
    if (node && !nodeStack.empty()) {
      nodeStack.back()->addChild(node);
    }
  }

  std::string getAttributeText(const MD_ATTRIBUTE *attr) {
    if (!attr || attr->size == 0 || !attr->text)
      return {};

    // Use string constructor directly - let SSO handle small strings efficiently
    // Empty return {} avoids allocating empty string object
    return std::string(attr->text, attr->size);
  }

  static int enterBlock(MD_BLOCKTYPE type, void *detail, void *userdata) {
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    switch (type) {
      case MD_BLOCK_DOC:
        // Document node already created in reset()
        break;

      case MD_BLOCK_P: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Paragraph));
        break;
      }

      case MD_BLOCK_H: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Heading);
        if (detail) {
          auto *h = static_cast<MD_BLOCK_H_DETAIL *>(detail);
          int level = static_cast<int>(h->level);
          // Clamp level to valid range (1-6)
          level = (level < 1) ? 1 : (level > 6) ? 6 : level;
          // Use char conversion for small integers (1-6)
          // Avoids std::to_string() allocation overhead
          char levelStr[2] = {static_cast<char>('0' + level), '\0'};
          node->setAttribute(ATTR_LEVEL, levelStr);
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_QUOTE: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Blockquote));
        break;
      }

      case MD_BLOCK_UL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::UnorderedList));
        break;
      }

      case MD_BLOCK_OL: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::OrderedList);
        if (detail) {
          auto *ol = static_cast<MD_BLOCK_OL_DETAIL *>(detail);
          if (ol->start != 1) {
            node->setAttribute(ATTR_START, std::to_string(ol->start));
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_LI: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::ListItem);
        if (detail) {
          auto *li = static_cast<MD_BLOCK_LI_DETAIL *>(detail);
          if (li->is_task) {
            node->setAttribute(ATTR_IS_TASK, "true");
            node->setAttribute(ATTR_TASK_CHECKED, (li->task_mark == 'x' || li->task_mark == 'X') ? "true" : "false");
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_CODE: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::CodeBlock);
        if (detail) {
          auto *codeDetail = static_cast<MD_BLOCK_CODE_DETAIL *>(detail);
          // Extract fence character (if fenced code block)
          if (codeDetail->fence_char != 0) {
            char fenceStr[2] = {static_cast<char>(codeDetail->fence_char), '\0'};
            node->setAttribute(ATTR_FENCE_CHAR, fenceStr);
          }
          // Extract language from lang attribute
          std::string lang = impl->getAttributeText(&codeDetail->lang);
          if (!lang.empty()) {
            node->setAttribute(ATTR_LANGUAGE, lang);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_HR: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::ThematicBreak));
        break;
      }

      case MD_BLOCK_TABLE: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Table);
        if (detail) {
          auto *tableDetail = static_cast<MD_BLOCK_TABLE_DETAIL *>(detail);
          node->setAttribute("colCount", std::to_string(tableDetail->col_count));
          node->setAttribute("headRowCount", std::to_string(tableDetail->head_row_count));
          node->setAttribute("bodyRowCount", std::to_string(tableDetail->body_row_count));
        }
        impl->pushNode(node);
        break;
      }

      case MD_BLOCK_THEAD: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableHead));
        break;
      }

      case MD_BLOCK_TBODY: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableBody));
        break;
      }

      case MD_BLOCK_TR: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::TableRow));
        break;
      }

      case MD_BLOCK_TH:
      case MD_BLOCK_TD: {
        auto node =
            std::make_shared<MarkdownASTNode>(type == MD_BLOCK_TH ? NodeType::TableHeaderCell : NodeType::TableCell);
        if (detail) {
          auto *tdDetail = static_cast<MD_BLOCK_TD_DETAIL *>(detail);
          const char *alignStr;
          switch (tdDetail->align) {
            case MD_ALIGN_LEFT:
              alignStr = "left";
              break;
            case MD_ALIGN_CENTER:
              alignStr = "center";
              break;
            case MD_ALIGN_RIGHT:
              alignStr = "right";
              break;
            default:
              alignStr = "default";
              break;
          }
          node->setAttribute("align", alignStr);
        }
        impl->pushNode(node);
        break;
      }

      default:
        // Other block types not yet implemented
        break;
    }

    return 0;
  }

  static int leaveBlock(MD_BLOCKTYPE type, void *detail, void *userdata) {
    (void)detail;
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    if (type != MD_BLOCK_DOC && !impl->nodeStack.empty()) {
      impl->popNode();
    }

    return 0;
  }

  static int enterSpan(MD_SPANTYPE type, void *detail, void *userdata) {
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    switch (type) {
      case MD_SPAN_A: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Link);
        if (detail) {
          auto *linkDetail = static_cast<MD_SPAN_A_DETAIL *>(detail);
          std::string url = impl->getAttributeText(&linkDetail->href);
          if (!url.empty()) {
            node->setAttribute(ATTR_URL, url);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_SPAN_STRONG: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strong));
        break;
      }

      case MD_SPAN_EM: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Emphasis));
        break;
      }

      case MD_SPAN_U: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Underline));
        break;
      }

      case MD_SPAN_CODE: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Code));
        break;
      }

      case MD_SPAN_DEL: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Strikethrough));
        break;
      }

      case MD_SPAN_IMG: {
        auto node = std::make_shared<MarkdownASTNode>(NodeType::Image);
        if (detail) {
          auto *imgDetail = static_cast<MD_SPAN_IMG_DETAIL *>(detail);
          std::string url = impl->getAttributeText(&imgDetail->src);
          if (!url.empty()) {
            node->setAttribute(ATTR_URL, url);
          }
          std::string title = impl->getAttributeText(&imgDetail->title);
          if (!title.empty()) {
            node->setAttribute(ATTR_TITLE, title);
          }
        }
        impl->pushNode(node);
        break;
      }

      case MD_SPAN_LATEXMATH: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::LatexMathInline));
        break;
      }

      case MD_SPAN_LATEXMATH_DISPLAY: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::LatexMathDisplay));
        break;
      }

      case MD_SPAN_SPOILER: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Spoiler));
        break;
      }

      case MD_SPAN_SUPERSCRIPT: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Superscript));
        break;
      }

      case MD_SPAN_SUBSCRIPT: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Subscript));
        break;
      }

      case MD_SPAN_MARK: {
        impl->pushNode(std::make_shared<MarkdownASTNode>(NodeType::Highlight));
        break;
      }

      default:
        break;
    }

    return 0;
  }

  static int leaveSpan(MD_SPANTYPE type, void *detail, void *userdata) {
    (void)detail;
    if (!userdata)
      return 1;
    auto *impl = static_cast<Impl *>(userdata);

    if (!impl->nodeStack.empty()) {
      impl->popNode();
    }

    return 0;
  }

  static int text(MD_TEXTTYPE type, const MD_CHAR *text, MD_SIZE size, void *userdata) {
    if (!userdata || !text || size == 0)
      return 0;
    auto *impl = static_cast<Impl *>(userdata);

    if (type == MD_TEXT_SOFTBR) {
      impl->addInlineNode(std::make_shared<MarkdownASTNode>(NodeType::SoftBreak));
      return 0;
    }

    if (type == MD_TEXT_BR) {
      impl->addInlineNode(std::make_shared<MarkdownASTNode>(NodeType::LineBreak));
      return 0;
    }

    // Handle text content (normal text, code text, LaTeX math, etc.)
    if (type == MD_TEXT_NORMAL || type == MD_TEXT_CODE || type == MD_TEXT_LATEXMATH) {
      impl->currentText.append(text, size);
    }

    return 0;
  }
};

namespace {

using NodeList = std::vector<std::shared_ptr<MarkdownASTNode>>;

bool isDisplayMathNode(const MarkdownASTNode &node) {
  return node.type == NodeType::LatexMathDisplay;
}

bool isSeparatorNode(const MarkdownASTNode &node) {
  return node.type == NodeType::LineBreak || node.type == NodeType::SoftBreak ||
         (node.type == NodeType::Text && node.content.find_first_not_of(" \t\n\r") == std::string::npos);
}

// A display-math node is "isolated" — i.e. block-level — when at least one of its
// neighbours is a boundary: the paragraph edge, or a separator (LineBreak / blank
// text). Display math flanked by real text on BOTH sides (e.g. `a $$x$$ b`) is
// genuinely inline and is left in place.
bool isIsolatedDisplayMath(const std::vector<std::shared_ptr<MarkdownASTNode>> &children, size_t i) {
  if (!isDisplayMathNode(*children[i]))
    return false;
  bool leftBoundary = (i == 0) || isSeparatorNode(*children[i - 1]);
  bool rightBoundary = (i + 1 >= children.size()) || isSeparatorNode(*children[i + 1]);
  return leftBoundary || rightBoundary;
}

// md4c parses $$...$$ as an inline span, so display math always lands nested inside a
// Paragraph — even when it sits on its own line, and even in the middle of a paragraph
// (text on lines before and after it, with no blank separator).
//
// This rebuilds such a paragraph into a sequence of top-level siblings so the rendering
// layer sees isolated display math as a block: each run of inline content becomes its own
// Paragraph, and each isolated display-math node becomes a bare LatexMathDisplay sibling.
// Separators bordering a promoted node are dropped. Returns an empty vector when the
// paragraph has no promotable display math, signalling the caller to leave it untouched.
//
// This subsumes the earlier trailing-only behaviour: pure (`$$x$$`), trailing
// (`text\n$$x$$`) and leading (`$$x$$\ntext`) are all just special cases of the general
// interior split.
std::vector<std::shared_ptr<MarkdownASTNode>>
splitParagraphAroundDisplayMath(const std::vector<std::shared_ptr<MarkdownASTNode>> &children) {
  bool anyPromotion = false;
  for (size_t i = 0; i < children.size(); ++i) {
    if (isIsolatedDisplayMath(children, i)) {
      anyPromotion = true;
      break;
    }
  }
  if (!anyPromotion)
    return {};

  std::vector<std::shared_ptr<MarkdownASTNode>> result;
  std::vector<std::shared_ptr<MarkdownASTNode>> inlineRun;

  auto flushInlineRun = [&]() {
    // Trim separators left dangling against the promoted math on either side.
    size_t start = 0;
    size_t end = inlineRun.size();
    while (start < end && isSeparatorNode(*inlineRun[start]))
      ++start;
    while (end > start && isSeparatorNode(*inlineRun[end - 1]))
      --end;
    if (start < end) {
      auto paragraph = std::make_shared<MarkdownASTNode>(NodeType::Paragraph);
      paragraph->children.assign(inlineRun.begin() + static_cast<NodeList::difference_type>(start),
                                 inlineRun.begin() + static_cast<NodeList::difference_type>(end));
      result.push_back(std::move(paragraph));
    }
    inlineRun.clear();
  };

  for (size_t i = 0; i < children.size(); ++i) {
    if (isIsolatedDisplayMath(children, i)) {
      flushInlineRun();
      result.push_back(children[i]);
    } else {
      inlineRun.push_back(children[i]);
    }
  }
  flushInlineRun();

  return result;
}

// Walk the document's top-level children and promote isolated display math out of its
// parent Paragraph so the rendering layer sees it as a top-level block element.
void promoteDisplayMathFromParagraphs(MarkdownASTNode &root) {
  auto &children = root.children;

  for (size_t i = 0; i < children.size();) {
    auto &paragraph = children[i];
    if (paragraph->type != NodeType::Paragraph || paragraph->children.empty()) {
      ++i;
      continue;
    }

    auto replacement = splitParagraphAroundDisplayMath(paragraph->children);
    if (replacement.empty()) {
      ++i;
      continue;
    }

    auto position = children.erase(children.begin() + static_cast<NodeList::difference_type>(i));
    children.insert(position, replacement.begin(), replacement.end());
    i += replacement.size();
  }
}

bool isBlockNode(const MarkdownASTNode &node) {
  switch (node.type) {
    case NodeType::Document:
    case NodeType::Paragraph:
    case NodeType::Heading:
    case NodeType::Blockquote:
    case NodeType::UnorderedList:
    case NodeType::OrderedList:
    case NodeType::ListItem:
    case NodeType::CodeBlock:
    case NodeType::ThematicBreak:
    case NodeType::LatexMathDisplay:
    case NodeType::Table:
    case NodeType::TableHead:
    case NodeType::TableBody:
    case NodeType::TableRow:
    case NodeType::TableHeaderCell:
    case NodeType::TableCell:
      return true;
    default:
      return false;
  }
}

// md4c omits Paragraph wrappers around the inline content of tight list items.
// Wrap each run of consecutive inline children of a ListItem in a synthetic
// Paragraph (marked "tight") so renderers only ever see block children.
void wrapListItemInlineRuns(MarkdownASTNode &node) {
  for (auto &child : node.children) {
    wrapListItemInlineRuns(*child);
  }

  if (node.type != NodeType::ListItem)
    return;

  bool hasInlineChild = false;
  for (auto &child : node.children) {
    if (!isBlockNode(*child)) {
      hasInlineChild = true;
      break;
    }
  }
  if (!hasInlineChild)
    return;

  std::vector<std::shared_ptr<MarkdownASTNode>> newChildren;
  newChildren.reserve(node.children.size());
  std::vector<std::shared_ptr<MarkdownASTNode>> run;

  auto flushRun = [&]() {
    if (run.empty())
      return;
    bool hasContent = false;
    for (auto &n : run) {
      if (!isSeparatorNode(*n)) {
        hasContent = true;
        break;
      }
    }
    if (hasContent) {
      auto paragraph = std::make_shared<MarkdownASTNode>(NodeType::Paragraph);
      paragraph->setAttribute("tight", "true");
      paragraph->children = std::move(run);
      newChildren.push_back(std::move(paragraph));
    } else {
      // Whitespace-only run between blocks — keep as-is, a paragraph would add spacing.
      for (auto &n : run) {
        newChildren.push_back(std::move(n));
      }
    }
    run.clear();
  };

  for (auto &child : node.children) {
    if (isBlockNode(*child)) {
      flushRun();
      newChildren.push_back(std::move(child));
    } else {
      run.push_back(std::move(child));
    }
  }
  flushRun();
  node.children = std::move(newChildren);
}

} // anonymous namespace

MD4CParser::MD4CParser() : impl_(std::make_unique<Impl>()) {}

MD4CParser::~MD4CParser() = default;

std::shared_ptr<MarkdownASTNode> MD4CParser::parse(const std::string &markdown, const Md4cFlags &md4cFlags) {
  if (markdown.empty()) {
    return std::make_shared<MarkdownASTNode>(NodeType::Document);
  }

  // Estimate stack depth based on markdown size
  // Heuristic: ~1 nesting level per 500-1000 characters for typical markdown
  // This is a rough estimate - actual depth depends on structure, not just size
  // Base depth of 12 covers typical nested structures (blockquotes, future lists)
  size_t estimatedDepth = 12; // Base depth for small documents
  if (markdown.size() > 1000) {
    // Scale up for larger documents, but cap the growth
    estimatedDepth = std::min(static_cast<size_t>(12 + (markdown.size() / 1000)), static_cast<size_t>(64));
  }

  impl_->reset(estimatedDepth);
  impl_->inputText = markdown.c_str();

  unsigned flags = MD_FLAG_NOHTML | MD_FLAG_STRIKETHROUGH | MD_FLAG_TABLES | MD_FLAG_TASKLISTS | MD_FLAG_SPOILERS;
  if (md4cFlags.permissiveAutolinks) {
    flags |= MD_FLAG_PERMISSIVEAUTOLINKS;
  }
  if (md4cFlags.latexMath) {
    flags |= MD_FLAG_LATEXMATHSPANS;
  }
  if (md4cFlags.underline) {
    flags |= MD_FLAG_UNDERLINE;
  }
  if (md4cFlags.superscript) {
    flags |= MD_FLAG_SUPERSCRIPTS;
  }
  if (md4cFlags.subscript) {
    flags |= MD_FLAG_SUBSCRIPTS;
  }
  if (md4cFlags.highlight) {
    flags |= MD_FLAG_HIGHLIGHT;
  }
  if (md4cFlags.hardSoftBreaks) {
    flags |= MD_FLAG_HARD_SOFT_BREAKS;
  }

  // Configure MD4C parser with callbacks
  MD_PARSER parser = {
      0, // abi_version
      flags,   &Impl::enterBlock, &Impl::leaveBlock, &Impl::enterSpan, &Impl::leaveSpan, &Impl::text,
      nullptr, // debug_log
      nullptr  // syntax
  };

  // Parse the markdown
  int result = md_parse(markdown.c_str(), static_cast<MD_SIZE>(markdown.size()), &parser, impl_.get());

  if (result != 0) {
    // Parsing failed, return empty document
    return std::make_shared<MarkdownASTNode>(NodeType::Document);
  }

  impl_->flushText();

  if (impl_->root) {
    promoteDisplayMathFromParagraphs(*impl_->root);
    wrapListItemInlineRuns(*impl_->root);
  }

  return impl_->root ? impl_->root : std::make_shared<MarkdownASTNode>(NodeType::Document);
}

// Static member definitions
const std::string MD4CParser::Impl::ATTR_LEVEL = "level";
const std::string MD4CParser::Impl::ATTR_URL = "url";
const std::string MD4CParser::Impl::ATTR_TITLE = "title";
const std::string MD4CParser::Impl::ATTR_FENCE_CHAR = "fenceChar";
const std::string MD4CParser::Impl::ATTR_LANGUAGE = "language";
const std::string MD4CParser::Impl::ATTR_IS_TASK = "isTask";
const std::string MD4CParser::Impl::ATTR_TASK_CHECKED = "taskChecked";
const std::string MD4CParser::Impl::ATTR_START = "start";

} // namespace Markdown
