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

// `[label](url)` or `![alt](url)` at the start of body.
BlockLineState bracketSyntaxState(const std::string &body) {
  return InlineSyntax::state(body, body[0] == '!' ? 1 : 0);
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
  if (body.rfind("<http", 0) == 0) {
    size_t close = body.find('>');
    if (close == std::string::npos)
      return BlockLineState::Open;
    return isBlank(body.substr(close + 1)) ? BlockLineState::Complete : BlockLineState::None;
  }
  if (body.rfind("http://", 0) == 0 || body.rfind("https://", 0) == 0 || body.rfind("www.", 0) == 0)
    return body.find_first_of(" \t") == std::string::npos ? BlockLineState::Open : BlockLineState::None;
  return BlockLineState::None;
}

} // namespace

namespace InlineSyntax {

bool isEscaped(const std::string &text, size_t index) {
  size_t backslashes = 0;
  while (index > backslashes && text[index - backslashes - 1] == '\\')
    backslashes++;
  return backslashes % 2 == 1;
}

bool insideCodeSpan(const std::string &text, size_t index) {
  size_t openRun = 0; // length of the backtick run that opened the current span
  size_t i = 0;
  while (i < index) {
    if (text[i] != '`') {
      i++;
      continue;
    }
    size_t run = 0;
    while (i < text.size() && text[i] == '`') {
      run++;
      i++;
    }
    if (openRun == 0)
      openRun = run;
    else if (run == openRun)
      openRun = 0;
  }
  return openRun != 0;
}

size_t labelEnd(const std::string &text, size_t bracket) {
  size_t depth = 0;
  for (size_t i = bracket; i < text.size(); i++) {
    char ch = text[i];
    if (ch == '\\') {
      i++; // the escaped character is literal
      continue;
    }
    if (ch != '[' && ch != ']')
      continue;
    if (insideCodeSpan(text, i))
      continue;
    if (ch == '[') {
      depth++;
    } else if (--depth == 0) {
      return i;
    }
  }
  return std::string::npos;
}

namespace {

bool isSpace(char ch) {
  return ch == ' ' || ch == '\t';
}

// The index just past a title that opens at `i` with `open` (`"`, `'` or `(`),
// or npos while its closing character has not arrived.
size_t titleEnd(const std::string &text, size_t i, char open) {
  char close = open == '(' ? ')' : open;
  for (i++; i < text.size(); i++) {
    if (text[i] == '\\') {
      i++;
      continue;
    }
    if (text[i] == close)
      return i + 1;
  }
  return std::string::npos;
}

} // namespace

size_t destinationEnd(const std::string &text, size_t openParen) {
  const size_t n = text.size();
  size_t i = openParen + 1;
  while (i < n && isSpace(text[i]))
    i++;
  if (i < n && text[i] == '<') {
    for (i++; i < n && text[i] != '>'; i++) {
      if (text[i] == '\\')
        i++;
    }
    if (i >= n)
      return std::string::npos;
    i++;
  } else {
    size_t depth = 0;
    while (i < n) {
      char ch = text[i];
      if (ch == '\\') {
        i += 2;
        continue;
      }
      if (isSpace(ch) || (ch == ')' && depth == 0))
        break;
      if (ch == '(')
        depth++;
      else if (ch == ')')
        depth--;
      i++;
    }
  }
  if (i >= n)
    return std::string::npos; // still typing the destination
  size_t afterDestination = i;
  while (i < n && isSpace(text[i]))
    i++;
  if (i >= n)
    return std::string::npos; // `[a](u ` may still get a title
  if (text[i] == ')')
    return i;
  // A title needs whitespace before it and one of three delimiters.
  if (i == afterDestination || (text[i] != '"' && text[i] != '\'' && text[i] != '('))
    return std::string::npos;
  i = titleEnd(text, i, text[i]);
  if (i == std::string::npos)
    return std::string::npos; // `[a](u "t` still typing the title
  while (i < n && isSpace(text[i]))
    i++;
  return i < n && text[i] == ')' ? i : std::string::npos;
}

BlockLineState state(const std::string &text, size_t bracket) {
  size_t close = labelEnd(text, bracket);
  if (close == std::string::npos)
    return BlockLineState::Open; // `[label` still typing
  if (isBlank(text.substr(close + 1)))
    return BlockLineState::Open; // `[label]`: the `(` may be next
  if (text[close + 1] != '(')
    return BlockLineState::None; // `[INFO] done`: prose
  size_t end = destinationEnd(text, close + 1);
  if (end == std::string::npos)
    return BlockLineState::Open; // `[label](https://e` still typing
  return isBlank(text.substr(end + 1)) ? BlockLineState::Complete : BlockLineState::None;
}

} // namespace InlineSyntax

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
