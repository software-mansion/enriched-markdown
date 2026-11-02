#include "BlockKinds.hpp"
#include "BlockSlots.hpp"
#include "TextScan.hpp"
#include <unordered_map>

namespace Markdown {

namespace {

const std::string kUrlAttribute = "url";
const std::string kTitleAttribute = "title";
const std::string kLanguageAttribute = "language";

void appendInlineText(const MarkdownASTNode &node, std::string &out) {
  if (!node.content.empty()) {
    out += node.content;
  } else if (node.type == NodeType::SoftBreak || node.type == NodeType::LineBreak) {
    out += ' ';
  }
  for (const auto &child : node.children) {
    appendInlineText(*child, out);
  }
}

// The stream may have stopped partway through `syntax` (`<vi` of `<video`).
bool isPartial(std::string_view body, std::string_view syntax) {
  return !body.empty() && body.size() < syntax.size() && startsWith(syntax, body);
}

// `[label](url)` or `![alt](url)` at the start of body.
BlockLineState bracketSyntaxState(std::string_view body) {
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

// The URL, the alt text and the title, all part of the id.
std::string imageFields(const MarkdownASTNode &image, BlockSlot &slot) {
  ImageSlotFields fields;
  fields.url = nodeAttribute(image, kUrlAttribute);
  fields.altText = inlineText(image);
  fields.title = nodeAttribute(image, kTitleAttribute);
  std::string identity = blockIdentity(fields.url, fields.altText, fields.title);
  slot.fields = std::move(fields);
  return identity;
}

BlockLineState imageLineState(std::string_view body) {
  if (isPartial(body, "!["))
    return BlockLineState::Open;
  return startsWith(body, "![") ? bracketSyntaxState(body) : BlockLineState::None;
}

// ---- video: a `<video src>` block

const MarkdownASTNode *videoMedia(const MarkdownASTNode &node) {
  return node.type == NodeType::Video ? &node : nullptr;
}

std::string videoFields(const MarkdownASTNode &video, BlockSlot &slot) {
  VideoSlotFields fields;
  fields.url = nodeAttribute(video, kUrlAttribute);
  std::string identity = blockIdentity(fields.url, std::string(), std::string());
  slot.fields = std::move(fields);
  return identity;
}

BlockLineState videoLineState(std::string_view body) {
  if (isPartial(body, "<video"))
    return BlockLineState::Open;
  if (!startsWith(body, "<video"))
    return BlockLineState::None;
  return body.find('>') == std::string_view::npos ? BlockLineState::Open : BlockLineState::Complete;
}

// ---- link: `[label](url)`, `<url>` or a bare URL on its own

const MarkdownASTNode *linkMedia(const MarkdownASTNode &node) {
  return onlyChildOfParagraph(node, NodeType::Link);
}

// The URL, the label and the title, all part of the id.
std::string linkFields(const MarkdownASTNode &link, BlockSlot &slot) {
  LinkSlotFields fields;
  fields.url = nodeAttribute(link, kUrlAttribute);
  fields.label = inlineText(link);
  fields.title = nodeAttribute(link, kTitleAttribute);
  std::string identity = blockIdentity(fields.url, fields.label, fields.title);
  slot.fields = std::move(fields);
  return identity;
}

BlockLineState linkLineState(std::string_view body) {
  if (startsWith(body, "[")) {
    // Not a link: a task box, a footnote or a reference definition (`[id]: url`).
    if (startsWith(body, "[ ]") || startsWith(body, "[x]") || startsWith(body, "[X]") || startsWith(body, "[^"))
      return BlockLineState::None;
    size_t open = body.find("](");
    size_t definition = body.find("]:");
    if (definition != std::string_view::npos && (open == std::string_view::npos || definition < open))
      return BlockLineState::None;
    return bracketSyntaxState(body);
  }
  // An `<autolink>` closes at `>`; a bare URL can always grow by another
  // character, so it stays open until something follows it.
  if (isPartial(body, "<http"))
    return BlockLineState::Open;
  if (startsWith(body, "<http")) {
    size_t close = body.find('>');
    if (close == std::string_view::npos)
      return BlockLineState::Open;
    return isBlankFrom(body, close + 1) ? BlockLineState::Complete : BlockLineState::None;
  }
  if (startsWith(body, "http://") || startsWith(body, "https://") || startsWith(body, "www."))
    return body.find_first_of(" \t") == std::string_view::npos ? BlockLineState::Open : BlockLineState::None;
  return BlockLineState::None;
}

// ---- code: a fenced or indented code block

const MarkdownASTNode *codeMedia(const MarkdownASTNode &node) {
  return node.type == NodeType::CodeBlock ? &node : nullptr;
}

void appendCode(const MarkdownASTNode &node, std::string &out) {
  out += node.content;
  for (const auto &child : node.children) {
    appendCode(*child, out);
  }
}

// The id hashes the language alone, so a fence keeps its id while its code
// streams in and when it closes.
std::string codeFields(const MarkdownASTNode &block, BlockSlot &slot) {
  CodeSlotFields fields;
  fields.language = nodeAttribute(block, kLanguageAttribute);
  appendCode(block, fields.code);
  while (!fields.code.empty() && fields.code.back() == '\n')
    fields.code.pop_back();
  std::string identity = fields.language;
  slot.fields = std::move(fields);
  return identity;
}

// The streaming filter cuts open fences by codeBlockMode, apart from mediaMode.
BlockLineState codeLineState(std::string_view) {
  return BlockLineState::None;
}

} // namespace

std::string nodeAttribute(const MarkdownASTNode &node, const std::string &key) {
  auto it = node.attributes.find(key);
  return it == node.attributes.end() ? std::string() : it->second;
}

std::string inlineText(const MarkdownASTNode &node) {
  std::string text;
  appendInlineText(node, text);
  size_t start = text.find_first_not_of(" \t\r\n");
  if (start == std::string::npos)
    return std::string();
  size_t end = text.find_last_not_of(" \t\r\n");
  return text.substr(start, end - start + 1);
}

namespace InlineSyntax {

bool isEscaped(std::string_view text, size_t index) {
  size_t backslashes = 0;
  while (index > backslashes && text[index - backslashes - 1] == '\\')
    backslashes++;
  return backslashes % 2 == 1;
}

CodeSpans::CodeSpans(std::string_view text) {
  struct Run {
    size_t start;
    size_t length;
  };
  std::vector<Run> runs;
  for (size_t i = 0; i < text.size();) {
    if (text[i] != '`') {
      i++;
      continue;
    }
    // An escaped first backtick is literal; the rest of the run still counts.
    size_t start = isEscaped(text, i) ? i + 1 : i;
    while (i < text.size() && text[i] == '`')
      i++;
    if (i > start)
      runs.push_back({start, i - start});
  }
  // The next run of the same length after each run, found right to left.
  std::vector<size_t> next(runs.size(), runs.size());
  std::unordered_map<size_t, size_t> lastOfLength;
  for (size_t r = runs.size(); r-- > 0;) {
    auto found = lastOfLength.find(runs[r].length);
    if (found != lastOfLength.end())
      next[r] = found->second;
    lastOfLength[runs[r].length] = r;
  }
  // A run opens a span when a later run of its length closes it; the runs in
  // between are inside the span.
  for (size_t r = 0; r < runs.size();) {
    if (next[r] == runs.size()) {
      r++;
      continue;
    }
    const Run &close = runs[next[r]];
    ranges.emplace_back(runs[r].start, close.start + close.length);
    r = next[r] + 1;
  }
}

size_t CodeSpans::Cursor::spanEndAt(size_t index) {
  while (next_ != end_ && next_->second <= index)
    ++next_;
  return next_ != end_ && next_->first <= index ? next_->second : std::string_view::npos;
}

size_t labelEnd(std::string_view text, size_t bracket, const CodeSpans &spans) {
  CodeSpans::Cursor code(spans);
  size_t depth = 0;
  for (size_t i = bracket; i < text.size(); i++) {
    size_t codeEnd = code.spanEndAt(i);
    if (codeEnd != std::string_view::npos) {
      i = codeEnd - 1;
      continue;
    }
    char ch = text[i];
    if (ch == '\\') {
      i++; // the escaped character is literal
      continue;
    }
    if (ch == '[') {
      depth++;
    } else if (ch == ']' && --depth == 0) {
      return i;
    }
  }
  return std::string_view::npos;
}

namespace {

bool isSpaceOrTab(char ch) {
  return ch == ' ' || ch == '\t';
}

// The index just past a title that opens at `i` with `open` (`"`, `'` or `(`),
// or npos while its closing character has not arrived.
size_t titleEnd(std::string_view text, size_t i, char open) {
  char close = open == '(' ? ')' : open;
  for (i++; i < text.size(); i++) {
    if (text[i] == '\\') {
      i++;
      continue;
    }
    if (text[i] == close)
      return i + 1;
  }
  return std::string_view::npos;
}

} // namespace

size_t destinationEnd(std::string_view text, size_t openParen, size_t *stop) {
  const size_t n = text.size();
  const size_t npos = std::string_view::npos;
  size_t i = openParen + 1;
  while (i < n && isSpaceOrTab(text[i]))
    i++;
  if (i < n && text[i] == '<') {
    for (i++; i < n && text[i] != '>'; i++) {
      if (text[i] == '\\')
        i++;
    }
    if (i >= n)
      return npos;
    i++;
  } else {
    size_t depth = 0;
    while (i < n) {
      char ch = text[i];
      if (ch == '\\') {
        i += 2;
        continue;
      }
      if (isSpaceOrTab(ch) || ch == '\n' || (ch == ')' && depth == 0))
        break;
      if (ch == '(')
        depth++;
      else if (ch == ')')
        depth--;
      i++;
    }
  }
  if (i >= n)
    return npos; // still typing the destination
  size_t afterDestination = i;
  while (i < n && (isSpaceOrTab(text[i]) || text[i] == '\n'))
    i++;
  if (i >= n)
    return npos; // `[a](u ` may still get a title
  if (text[i] == ')')
    return i;
  // A title needs whitespace before it and one of three delimiters.
  if (i == afterDestination || (text[i] != '"' && text[i] != '\'' && text[i] != '(')) {
    if (stop != nullptr)
      *stop = i;
    return kInvalid;
  }
  i = titleEnd(text, i, text[i]);
  if (i == npos)
    return npos; // `[a](u "t` still typing the title
  while (i < n && (isSpaceOrTab(text[i]) || text[i] == '\n'))
    i++;
  if (i >= n)
    return npos;
  if (text[i] == ')')
    return i;
  if (stop != nullptr)
    *stop = i;
  return kInvalid;
}

BlockLineState state(std::string_view text, size_t bracket) {
  size_t close = labelEnd(text, bracket, CodeSpans(text));
  if (close == std::string_view::npos)
    return BlockLineState::Open; // `[label` still typing
  if (isBlankFrom(text, close + 1))
    return BlockLineState::Open; // `[label]`: the `(` may be next
  if (text[close + 1] != '(')
    return BlockLineState::None; // `[INFO] done`: prose
  size_t end = destinationEnd(text, close + 1);
  if (end == std::string_view::npos)
    return BlockLineState::Open; // `[label](https://e` still typing
  if (end == kInvalid)
    return BlockLineState::None; // `[label](u then prose`
  return isBlankFrom(text, end + 1) ? BlockLineState::Complete : BlockLineState::None;
}

} // namespace InlineSyntax

// Order matters where a node could match two kinds: none do today.
const BlockKind kBlockKinds[kBlockKindCount] = {
    {BlockSlotKind::Image, "image", imageMedia, imageFields, false, imageLineState},
    {BlockSlotKind::Video, "video", videoMedia, videoFields, false, videoLineState},
    // The link's content (a linked image, say) still walks for image occurrences.
    {BlockSlotKind::Link, "link", linkMedia, linkFields, true, linkLineState},
    {BlockSlotKind::Code, "code", codeMedia, codeFields, false, codeLineState},
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
