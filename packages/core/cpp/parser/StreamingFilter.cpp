#include "StreamingFilter.hpp"
#include "BlockKinds.hpp"
#include "TextScan.hpp"
#include <algorithm>
#include <cctype>
#include <string_view>
#include <unordered_set>
#include <vector>

namespace Markdown {

namespace {

constexpr size_t npos = std::string_view::npos;

// One line of the document, a view into it, split once per call.
struct Line {
  std::string_view text;
  size_t offset; // of its first character in the document
  bool code;     // inside a fenced code block, fence lines included
};
using Lines = std::vector<Line>;

// The part of the document still shown, and its lines. Every rule below cuts
// the document at a line start or inside the last paragraph, so the lines are
// truncated instead of split again.
struct Document {
  std::string_view text;
  Lines lines;

  void cutAtLine(size_t index) {
    size_t offset = lines[index].offset;
    text = text.substr(0, offset);
    lines.resize(index);
    // The text now ends with the newline before the cut line, or is empty.
    lines.push_back({std::string_view(), offset, false});
  }
};

Lines splitLines(std::string_view text) {
  Lines lines;
  size_t start = 0;
  while (true) {
    size_t end = text.find('\n', start);
    if (end == npos) {
      lines.push_back({text.substr(start), start, false});
      return lines;
    }
    lines.push_back({text.substr(start, end - start), start, false});
    start = end + 1;
  }
}

std::string_view trim(std::string_view text) {
  size_t start = 0;
  while (start < text.size() && isWhitespace(text[start]))
    start++;
  size_t end = text.size();
  while (end > start && isWhitespace(text[end - 1]))
    end--;
  return text.substr(start, end - start);
}

size_t leadingSpaces(std::string_view text) {
  size_t i = 0;
  while (i < text.size() && text[i] == ' ')
    i++;
  return i;
}

// ---- containers

// A line without its blockquote markers.
struct Quoted {
  std::string_view body;
  size_t depth;
};

Quoted stripQuotes(std::string_view line) {
  size_t depth = 0;
  size_t i = 0;
  while (true) {
    size_t j = i;
    while (j < line.size() && line[j] == ' ' && j - i < 3)
      j++;
    if (j >= line.size() || line[j] != '>')
      break;
    depth++;
    j++;
    if (j < line.size() && (line[j] == ' ' || line[j] == '\t'))
      j++;
    i = j;
  }
  return {line.substr(i), depth};
}

// A line that holds only quote markers ends a paragraph like an empty line.
bool lineIsBlank(const Line &line) {
  return isBlank(stripQuotes(line.text).body);
}

// The width of a list item marker at the start of `body` with the spaces after
// it (the column the item's content starts at), or 0.
size_t listMarkerWidth(std::string_view body) {
  size_t i = leadingSpaces(body);
  if (i > 3 || i >= body.size())
    return 0;
  size_t m = i;
  if (body[m] == '-' || body[m] == '*' || body[m] == '+') {
    m++;
  } else {
    size_t digits = m;
    while (digits < body.size() && digits - m < 9 && std::isdigit(static_cast<unsigned char>(body[digits])))
      digits++;
    if (digits == m || digits >= body.size() || (body[digits] != '.' && body[digits] != ')'))
      return 0;
    m = digits + 1;
  }
  if (m == body.size())
    return m;
  if (body[m] != ' ' && body[m] != '\t')
    return 0;
  size_t content = m;
  while (content < body.size() && body[content] == ' ' && content - m < 4)
    content++;
  return content;
}

bool isAtxHeading(std::string_view body) {
  size_t indent = leadingSpaces(body);
  if (indent > 3)
    return false;
  std::string_view text = body.substr(indent);
  size_t hashes = 0;
  while (hashes < text.size() && text[hashes] == '#')
    hashes++;
  return hashes >= 1 && hashes <= 6 && (hashes == text.size() || text[hashes] == ' ');
}

bool startsOwnBlock(std::string_view body) {
  return listMarkerWidth(body) != 0 || isAtxHeading(body);
}

// A setext underline (`===`, `---`) or a thematic break (`***`, `- - -`): it
// ends the block above it, and the line after it starts a new one.
bool isUnderlineOrBreak(std::string_view body) {
  if (leadingSpaces(body) > 3)
    return false;
  std::string_view text = trim(body);
  if (text.empty())
    return false;
  char ch = text[0];
  if ((ch == '=' || ch == '-') && text.find_first_not_of(ch) == npos)
    return true;
  if (ch != '*' && ch != '-' && ch != '_')
    return false;
  size_t marks = 0;
  for (char c : text) {
    if (c == ch)
      marks++;
    else if (!isWhitespace(c))
      return false;
  }
  return marks >= 3;
}

// ---- fenced code and reference definitions, in one forward scan

struct FenceMarker {
  char ch = 0;
  size_t length = 0;
  std::string_view info;
};

bool parseFenceMarker(std::string_view line, FenceMarker &out) {
  size_t i = 0;
  while (i < line.size() && line[i] == ' ' && i < 3)
    i++;
  if (i >= line.size())
    return false;
  char ch = line[i];
  if (ch != '`' && ch != '~')
    return false;
  size_t run = 0;
  while (i < line.size() && line[i] == ch) {
    i++;
    run++;
  }
  if (run < 3)
    return false;
  std::string_view info = line.substr(i);
  if (ch == '`' && info.find('`') != npos)
    return false;
  out = {ch, run, info};
  return true;
}

// Reference labels match case-insensitively with whitespace runs collapsed.
std::string normalizeLabel(std::string_view label) {
  std::string normalized;
  bool space = false;
  for (char ch : trim(label)) {
    if (isWhitespace(ch) || ch == '\n') {
      space = true;
      continue;
    }
    if (space && !normalized.empty())
      normalized += ' ';
    space = false;
    normalized += static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
  }
  return normalized;
}

void recordDefinition(std::string_view content, std::unordered_set<std::string> &definitions) {
  std::string_view text = content.substr(std::min(leadingSpaces(content), content.size()));
  if (text.empty() || text[0] != '[' || startsWith(text, "[^"))
    return;
  size_t close = text.find("]:");
  if (close == npos || close == 1)
    return;
  definitions.insert(normalizeLabel(text.substr(1, close - 1)));
}

struct BlockScan {
  size_t openFence = npos; // the opening line of a fence still open at the end
  std::unordered_set<std::string> definitions;
};

// Marks the fenced code lines and finds the open fence and the reference
// definitions. Fences inside blockquotes and list items count: a quoted fence
// closes with its quote, a listed one when a line leaves the item's indent.
BlockScan scanBlocks(Lines &lines) {
  BlockScan scan;
  struct {
    char ch = 0;
    size_t length = 0;
    size_t depth = 0;
    size_t indent = 0;
  } fence;
  bool inFence = false;
  size_t listIndent = 0; // content column of the list item being continued
  for (size_t i = 0; i < lines.size(); i++) {
    Quoted quoted = stripQuotes(lines[i].text);
    std::string_view body = quoted.body;
    bool blank = isBlank(body);
    size_t lead = leadingSpaces(body);
    if (inFence) {
      bool containerEnded = quoted.depth < fence.depth || (!blank && lead < fence.indent);
      if (!containerEnded) {
        lines[i].code = true;
        FenceMarker marker;
        if (!blank && parseFenceMarker(body.substr(fence.indent), marker) && marker.ch == fence.ch &&
            marker.length >= fence.length && isBlank(marker.info))
          inFence = false;
        continue;
      }
      inFence = false;
    }
    if (blank)
      continue;
    std::string_view content = body;
    size_t indent = 0;
    if (size_t marker = listMarkerWidth(body)) {
      listIndent = marker;
      indent = marker;
    } else if (listIndent != 0 && lead >= listIndent) {
      indent = listIndent;
    } else {
      listIndent = 0;
    }
    content = body.substr(indent);
    FenceMarker marker;
    if (parseFenceMarker(content, marker)) {
      inFence = true;
      fence = {marker.ch, marker.length, quoted.depth, indent};
      lines[i].code = true;
      scan.openFence = i;
      continue;
    }
    recordDefinition(content, scan.definitions);
  }
  if (!inFence)
    scan.openFence = npos;
  return scan;
}

// ---- the trailing block

// The last line that is not blank, or npos.
size_t lastNonBlankLine(const Lines &lines) {
  for (size_t i = lines.size(); i-- > 0;) {
    if (!lineIsBlank(lines[i]))
      return i;
  }
  return npos;
}

// A trailing block is still arriving unless a blank line follows it, i.e. the
// document ends more than one newline after its last non-blank line.
bool trailingBlockIsOpen(const Lines &lines, size_t last) {
  return last != npos && last + 2 >= lines.size();
}

size_t blockStart(const Lines &lines, size_t last) {
  size_t start = last;
  while (start > 0 && !lineIsBlank(lines[start - 1]) && !lines[start - 1].code)
    start--;
  return start;
}

// ---- block math

void cutPendingMath(Document &doc) {
  size_t unclosed = npos;
  for (size_t i = 0; i < doc.lines.size(); i++) {
    if (!doc.lines[i].code && trim(stripQuotes(doc.lines[i].text).body) == "$$")
      unclosed = unclosed == npos ? i : npos;
  }
  if (unclosed != npos)
    doc.cutAtLine(unclosed);
}

// ---- tables

std::string_view tableRow(const Line &line) {
  return trim(stripQuotes(line.text).body);
}

// The cells of a row, without the optional outer pipes.
std::vector<std::string_view> tableCells(std::string_view row) {
  if (!row.empty() && row.front() == '|')
    row.remove_prefix(1);
  if (!row.empty() && row.back() == '|' && !InlineSyntax::isEscaped(row, row.size() - 1))
    row.remove_suffix(1);
  std::vector<std::string_view> cells;
  size_t start = 0;
  for (size_t i = 0; i <= row.size(); i++) {
    if (i == row.size() || (row[i] == '|' && !InlineSyntax::isEscaped(row, i))) {
      cells.push_back(trim(row.substr(start, i - start)));
      start = i + 1;
    }
  }
  return cells;
}

bool isDelimiterRow(std::string_view row, size_t headerCells) {
  if (row.find('-') == npos)
    return false;
  auto cells = tableCells(row);
  if (cells.size() != headerCells)
    return false;
  for (auto cell : cells) {
    if (!cell.empty() && cell.front() == ':')
      cell.remove_prefix(1);
    if (!cell.empty() && cell.back() == ':')
      cell.remove_suffix(1);
    if (cell.empty() || cell.find_first_not_of('-') != npos)
      return false;
  }
  return true;
}

size_t pipeCount(std::string_view row) {
  size_t count = 0;
  for (size_t i = 0; i < row.size(); i++) {
    if (row[i] == '|' && !InlineSyntax::isEscaped(row, i))
      count++;
  }
  return count;
}

void cutPendingTable(Document &doc, StreamingBlockMode mode) {
  const Lines &lines = doc.lines;
  size_t last = lastNonBlankLine(lines);
  if (!trailingBlockIsOpen(lines, last))
    return;
  size_t start = blockStart(lines, last);
  if (lines[start].code)
    return;
  std::string_view header = tableRow(lines[start]);
  size_t lineCount = last - start + 1;
  bool hasDelimiter = lineCount >= 2 && isDelimiterRow(tableRow(lines[start + 1]), tableCells(header).size());
  bool piped = true;
  for (size_t i = start; i <= last; i++) {
    if (tableRow(lines[i]).front() != '|')
      piped = false;
  }
  // A row of pipes may become a table; without outer pipes only the delimiter
  // row tells a table from prose that holds a `|`.
  if (!piped && (!hasDelimiter || header.find('|') == npos))
    return;

  if (mode == StreamingBlockMode::Hidden || !hasDelimiter) {
    doc.cutAtLine(start);
    return;
  }
  if (lineCount > 2) {
    std::string_view lastRow = tableRow(lines[last]);
    if ((piped && lastRow.back() != '|') || pipeCount(lastRow) < pipeCount(header))
      doc.cutAtLine(last);
  }
}

// ---- media and inline syntax

// HTML blocks whose content is raw: nothing in them is Markdown to cut.
bool startsRawHtmlBlock(std::string_view body) {
  static const char *const kOpeners[] = {"<!--",   "<pre",    "<script",  "<style", "<div", "<details", "<summary",
                                         "<table", "<figure", "<section", "<p>",    "<p ",  "<center"};
  for (const char *opener : kOpeners) {
    if (startsWith(body, opener))
      return true;
  }
  return false;
}

// Whether the line is a block a slot can replace (one of kBlockKinds) and
// whether its syntax has closed.
BlockLineState classifyMediaLine(std::string_view body) {
  for (const auto &kind : kBlockKinds) {
    BlockLineState state = kind.lineState(body);
    if (state != BlockLineState::None)
      return state;
  }
  return BlockLineState::None;
}

// A label still typed this far past its `[` is prose with a stray bracket, not
// a link: it stops withholding the rest of the paragraph.
constexpr size_t kMaxOpenLabel = 512;

// Where an inline image or link whose syntax is still open starts in the
// paragraph (`![alt](https://`, `[label](ur`, or a `[label]` the `(` may still
// follow), or npos when it ends cleanly. One pass: escapes and code spans are
// prose, brackets nest, and a label followed by a defined reference is a
// complete link.
size_t openInlineSyntaxStart(std::string_view text, const std::unordered_set<std::string> &definitions) {
  InlineSyntax::CodeSpans spans(text);
  InlineSyntax::CodeSpans::Cursor code(spans);
  std::vector<size_t> openers;
  // Where the last destination found to be prose gave up. A `](` before it
  // sits inside that destination and would rescan the same text to the same
  // end, which makes `[x](` repeated quadratic.
  size_t proseUntil = 0;
  // The outermost construct still open when `innermost` is: the earliest
  // opener within kMaxOpenLabel of the end, the `!` of an image included.
  auto openFrom = [&](size_t innermost) {
    size_t window = text.size() > kMaxOpenLabel ? text.size() - kMaxOpenLabel : 0;
    auto outer = std::lower_bound(openers.begin(), openers.end(), window);
    size_t start = outer != openers.end() ? *outer : innermost;
    if (start < window)
      return npos;
    // An escaped `!` is literal text; the link after it is still a link.
    bool image = start > 0 && text[start - 1] == '!' && !InlineSyntax::isEscaped(text, start - 1);
    return image ? start - 1 : start;
  };
  for (size_t i = 0; i < text.size(); i++) {
    size_t codeEnd = code.spanEndAt(i);
    if (codeEnd != npos) {
      i = codeEnd - 1;
      continue;
    }
    char ch = text[i];
    if (ch == '\\') {
      i++;
      continue;
    }
    if (ch == '[') {
      openers.push_back(i);
      continue;
    }
    if (ch != ']' || openers.empty())
      continue;
    size_t opener = openers.back();
    openers.pop_back();
    size_t after = i + 1;
    if (isBlankFrom(text, after))
      return openFrom(opener); // `[label]`: the `(` may be next
    if (text[after] == '(') {
      if (after < proseUntil)
        continue;
      size_t stop = npos;
      size_t end = InlineSyntax::destinationEnd(text, after, &stop);
      if (end == npos)
        return openFrom(opener);
      if (end == InlineSyntax::kInvalid)
        proseUntil = stop;
      else
        i = end;
      continue;
    }
    if (text[after] == '[') {
      size_t refEnd = text.find(']', after + 1);
      if (refEnd != npos) {
        std::string_view ref = text.substr(after + 1, refEnd - after - 1);
        if (ref.empty())
          ref = text.substr(opener + 1, i - opener - 1);
        if (definitions.count(normalizeLabel(ref)) != 0)
          i = refEnd;
      }
    }
  }
  return openers.empty() ? npos : openFrom(openers.back());
}

// The first line of the paragraph that ends at `last`. A line that opens its
// own block (a list item, a heading, a deeper quote, an HTML block) starts it;
// one that cannot continue (a heading, an underline, a break) ends the block
// before it.
size_t paragraphStart(const Lines &lines, size_t start, size_t last) {
  size_t line = last;
  while (line > start) {
    Quoted current = stripQuotes(lines[line].text);
    Quoted previous = stripQuotes(lines[line - 1].text);
    std::string_view content = current.body.substr(std::min(leadingSpaces(current.body), current.body.size()));
    if (startsOwnBlock(current.body) || isUnderlineOrBreak(current.body) || startsRawHtmlBlock(content) ||
        current.depth > previous.depth || isAtxHeading(previous.body) || isUnderlineOrBreak(previous.body))
      break;
    line--;
  }
  return line;
}

// The paragraph ends in an image or link still being typed: cut that syntax so
// it never shows as literal text.
void cutOpenInlineSyntax(Document &doc, size_t start, size_t last, const BlockScan &scan) {
  size_t paragraph = paragraphStart(doc.lines, start, last);
  std::string_view body = stripQuotes(doc.lines[paragraph].text).body;
  if (startsRawHtmlBlock(body.substr(std::min(leadingSpaces(body), body.size()))))
    return;
  size_t offset = doc.lines[paragraph].offset;
  size_t open = openInlineSyntaxStart(doc.text.substr(offset), scan.definitions);
  if (open != npos)
    doc.text = doc.text.substr(0, offset + open);
}

// `terminated` says another block (an open code fence) follows the text, which
// closes a trailing paragraph the way a blank line does.
void cutPendingMedia(Document &doc, StreamingBlockMode mode, bool terminated, const BlockScan &scan) {
  const Lines &lines = doc.lines;
  size_t last = lastNonBlankLine(lines);
  if (!trailingBlockIsOpen(lines, last) || lines[last].code)
    return;
  size_t start = blockStart(lines, last);
  std::string_view firstBody = stripQuotes(lines[start].text).body;
  size_t firstIndent = leadingSpaces(firstBody);
  std::string_view firstContent = firstBody.substr(firstIndent);
  if (firstIndent >= 4 || startsRawHtmlBlock(firstContent))
    return; // indented code or raw HTML

  std::string_view body = stripQuotes(lines[last].text).body;
  size_t indent = leadingSpaces(body);
  BlockLineState state = indent < 4 ? classifyMediaLine(body.substr(indent)) : BlockLineState::None;
  size_t cutOffset = lines[last].offset;
  // A `<video` tag may wrap over several lines: it is open until its `>`.
  if (state == BlockLineState::None && start != last && startsWith(firstContent, "<video")) {
    size_t tagStart = static_cast<size_t>(firstContent.data() - doc.text.data());
    state = doc.text.find('>', tagStart) == npos ? BlockLineState::Open : BlockLineState::Complete;
    cutOffset = lines[start].offset;
  }

  if (state == BlockLineState::None) {
    if (!terminated)
      cutOpenInlineSyntax(doc, start, last, scan);
    return;
  }
  if (state == BlockLineState::Complete && (mode == StreamingBlockMode::Progressive || terminated))
    return;
  doc.text = doc.text.substr(0, cutOffset);
}

std::string_view removePendingBlocks(Document doc, const StreamingFilterOptions &options, bool terminated,
                                     const BlockScan &scan) {
  cutPendingMath(doc);
  cutPendingTable(doc, options.tableMode);
  cutPendingMedia(doc, options.mediaMode, terminated, scan);
  return doc.text;
}

} // namespace

StreamingFilterResult renderableMarkdownForStreaming(const std::string &markdown,
                                                     const StreamingFilterOptions &options) {
  std::string_view text(markdown);
  Lines lines = splitLines(text);
  BlockScan scan = scanBlocks(lines);
  if (scan.openFence == npos)
    return {std::string(removePendingBlocks({text, std::move(lines)}, options, false, scan)), false};

  // The fence terminates whatever paragraph precedes it, shown or not.
  Document head{text, std::move(lines)};
  size_t fenceOffset = head.lines[scan.openFence].offset;
  head.cutAtLine(scan.openFence);
  std::string_view kept = removePendingBlocks(std::move(head), options, true, scan);
  if (options.codeBlockMode == StreamingBlockMode::Hidden)
    return {std::string(kept), false};
  std::string result;
  result.reserve(kept.size() + text.size() - fenceOffset);
  result.append(kept).append(text.substr(fenceOffset));
  return {std::move(result), true};
}

StreamingBlockMode streamingBlockModeFromName(const std::string &name) {
  return name == "hidden" ? StreamingBlockMode::Hidden : StreamingBlockMode::Progressive;
}

} // namespace Markdown
