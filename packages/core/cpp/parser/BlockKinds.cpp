#include "BlockKinds.hpp"

namespace Markdown {

namespace {

bool isBlank(const std::string &text) {
  for (char ch : text) {
    if (ch != ' ' && ch != '\t' && ch != '\r' && ch != '\f' && ch != '\v')
      return false;
  }
  return true;
}

// `[label](url)` or `![alt](url)` from the start of body: Open while the syntax
// has not closed, Complete when nothing but whitespace follows it, None when the
// line goes on (a text paragraph that merely starts with a link or image).
BlockLineState bracketSyntaxState(const std::string &body) {
  size_t open = body.find("](");
  if (open == std::string::npos)
    return BlockLineState::Open;
  size_t close = body.find(')', open + 2);
  if (close == std::string::npos)
    return BlockLineState::Open;
  return isBlank(body.substr(close + 1)) ? BlockLineState::Complete : BlockLineState::None;
}

// A paragraph whose only child is `type`.
const MarkdownASTNode *onlyChildOfParagraph(const MarkdownASTNode &node, NodeType type) {
  if (node.type != NodeType::Paragraph || node.children.size() != 1 || node.children[0]->type != type)
    return nullptr;
  return node.children[0].get();
}

// ---- image: `![alt](url)` on its own

const MarkdownASTNode *imageMedia(const MarkdownASTNode &node) {
  return onlyChildOfParagraph(node, NodeType::Image);
}

BlockLineState imageLineState(const std::string &body) {
  return body.rfind("![", 0) == 0 ? bracketSyntaxState(body) : BlockLineState::None;
}

// ---- video: a `<video src>` block

const MarkdownASTNode *videoMedia(const MarkdownASTNode &node) {
  return node.type == NodeType::Video ? &node : nullptr;
}

BlockLineState videoLineState(const std::string &body) {
  if (body.rfind("<video", 0) != 0)
    return BlockLineState::None;
  return body.find('>') == std::string::npos ? BlockLineState::Open : BlockLineState::Complete;
}

// ---- link: `[label](url)`, `<url>` or a bare URL on its own

const MarkdownASTNode *linkMedia(const MarkdownASTNode &node) {
  return onlyChildOfParagraph(node, NodeType::Link);
}

BlockLineState linkLineState(const std::string &body) {
  if (body.rfind("[", 0) == 0) {
    // Not a link: a task box, a footnote or a reference definition (`[id]: url`).
    if (body.rfind("[ ]", 0) == 0 || body.rfind("[x]", 0) == 0 || body.rfind("[X]", 0) == 0 || body.rfind("[^", 0) == 0)
      return BlockLineState::None;
    size_t open = body.find("](");
    size_t definition = body.find("]:");
    if (definition != std::string::npos && (open == std::string::npos || definition < open))
      return BlockLineState::None;
    return bracketSyntaxState(body);
  }
  // An `<autolink>` closes at `>`; a bare URL can always grow by another
  // character, so it stays open until something follows it.
  if (body.rfind("<http", 0) == 0)
    return body.find('>') == std::string::npos ? BlockLineState::Open : BlockLineState::Complete;
  if (body.rfind("http://", 0) == 0 || body.rfind("https://", 0) == 0 || body.rfind("www.", 0) == 0)
    return body.find_first_of(" \t") == std::string::npos ? BlockLineState::Open : BlockLineState::None;
  return BlockLineState::None;
}

} // namespace

// Order matters where a node could match two kinds: none do today.
const BlockKind kBlockKinds[kBlockKindCount] = {
    {BlockSlotKind::Image, "image", imageMedia, true, true, false, imageLineState},
    {BlockSlotKind::Video, "video", videoMedia, false, false, false, videoLineState},
    // The link's content (a linked image, say) still walks for image occurrences.
    {BlockSlotKind::Link, "link", linkMedia, true, false, true, linkLineState},
};

const BlockKind &blockKindFor(BlockSlotKind kind) {
  for (const auto &entry : kBlockKinds) {
    if (entry.kind == kind)
      return entry;
  }
  return kBlockKinds[0];
}

const BlockKind *blockKindNamed(const std::string &name) {
  for (const auto &entry : kBlockKinds) {
    if (name == entry.name)
      return &entry;
  }
  return nullptr;
}

} // namespace Markdown
