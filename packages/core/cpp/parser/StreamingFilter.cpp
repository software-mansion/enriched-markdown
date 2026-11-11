#include "StreamingFilter.hpp"
#include "BlockKinds.hpp"
#include "TextScan.hpp"
#include <algorithm>
#include <cctype>
#include <string_view>
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

// ---- fenced code, in one forward scan

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

// Marks the fenced code lines and returns the opening line of a fence still
// open at the end, or npos. Fences inside blockquotes and list items count: a
// quoted fence closes with its quote, a listed one when a line leaves the
// item's indent.
size_t scanFences(Lines &lines) {
  size_t openFence = npos;
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
      // A blank last line has not streamed its quote markers in yet, so it cannot
      // end a quoted fence.
      bool undecided = i + 1 == lines.size() && isBlank(lines[i].text);
      bool containerEnded = !undecided && (quoted.depth < fence.depth || (!blank && lead < fence.indent));
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
      openFence = i;
    }
  }
  return inFence ? openFence : npos;
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

bool equalsIgnoringCase(char a, char b) {
  return std::tolower(static_cast<unsigned char>(a)) == std::tolower(static_cast<unsigned char>(b));
}

// HTML blocks whose content is raw: nothing in them is Markdown to cut. Tag names compare as md4c
// does, ignoring case and ending at a space, `>` or the line's end.
bool startsRawHtmlBlock(std::string_view body) {
  if (startsWith(body, "<!--"))
    return true;
  static const std::string_view kTags[] = {"pre",   "script", "style",   "div", "details", "summary",
                                           "table", "figure", "section", "p",   "center"};
  if (body.empty() || body[0] != '<')
    return false;
  for (std::string_view tag : kTags) {
    size_t after = tag.size() + 1;
    if (body.size() >= after && std::equal(tag.begin(), tag.end(), body.begin() + 1, equalsIgnoringCase) &&
        (after == body.size() || body[after] == ' ' || body[after] == '\t' || body[after] == '>'))
      return true;
  }
  return false;
}

bool containsIgnoringCase(std::string_view text, std::string_view needle) {
  return std::search(text.begin(), text.end(), needle.begin(), needle.end(), equalsIgnoringCase) != text.end();
}

// HTML blocks that may hold blank lines (CommonMark types 1-5) end at a closing text, not at a blank
// line: the text that closes the one `body` opens, empty when it opens none. Tag names compare as
// md4c does, ignoring case and ending at a space, `>` or the line's end.
std::string_view htmlBlockCloser(std::string_view body) {
  std::string_view text = body.substr(std::min(leadingSpaces(body), body.size()));
  if (startsWith(text, "<!--"))
    return "-->";
  if (startsWith(text, "<![CDATA["))
    return "]]>";
  if (startsWith(text, "<?"))
    return "?>";
  if (text.size() > 2 && startsWith(text, "<!") && std::isalpha(static_cast<unsigned char>(text[2])))
    return ">";
  static const std::string_view kRawTags[][2] = {
      {"pre", "</pre>"}, {"script", "</script>"}, {"style", "</style>"}, {"textarea", "</textarea>"}};
  for (const auto &tag : kRawTags) {
    std::string_view name = tag[0];
    if (text.size() <= name.size() || text[0] != '<' ||
        !std::equal(name.begin(), name.end(), text.begin() + 1, equalsIgnoringCase))
      continue;
    size_t after = name.size() + 1;
    if (after == text.size() || text[after] == ' ' || text[after] == '\t' || text[after] == '>')
      return tag[1];
  }
  return {};
}

// A line that starts a block of its own at the top level: not indented (code,
// or a list item's continuation), and no list marker, reference definition,
// footnote or HTML that could belong to the block above.
bool startsTopLevelBlock(std::string_view line) {
  if (line.empty())
    return false;
  char ch = line[0];
  return !(isWhitespace(ch) || ch == '-' || ch == '*' || ch == '+' || ch == '[' || ch == '<' ||
           std::isdigit(static_cast<unsigned char>(ch)));
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

// `terminated` says another block (an open code fence) follows the text, which
// closes a trailing paragraph the way a blank line does.
void cutPendingMedia(Document &doc, StreamingBlockMode mode, bool terminated) {
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

  if (state == BlockLineState::None)
    return; // prose; repair handles inline syntax still being typed
  if (state == BlockLineState::Complete && (mode == StreamingBlockMode::Progressive || terminated))
    return;
  doc.text = doc.text.substr(0, cutOffset);
}

std::string_view removePendingBlocks(Document doc, const StreamingFilterOptions &options, bool terminated) {
  cutPendingMath(doc);
  cutPendingTable(doc, options.tableMode);
  cutPendingMedia(doc, options.mediaMode, terminated);
  return doc.text;
}

} // namespace

StreamingFilterResult renderableMarkdownForStreaming(const std::string &markdown,
                                                     const StreamingFilterOptions &options) {
  std::string_view text(markdown);
  Lines lines = splitLines(text);
  size_t openFence = scanFences(lines);
  if (openFence == npos)
    return {std::string(removePendingBlocks({text, std::move(lines)}, options, false)), false};

  // The fence terminates whatever paragraph precedes it, shown or not. Until its
  // opening line ends the info string may still grow, so the fence waits for it
  // and its language never changes while it shows.
  bool openerEnded = openFence + 1 < lines.size();
  Document head{text, std::move(lines)};
  size_t fenceOffset = head.lines[openFence].offset;
  head.cutAtLine(openFence);
  std::string_view kept = removePendingBlocks(std::move(head), options, true);
  if (options.codeBlockMode == StreamingBlockMode::Hidden || !openerEnded)
    return {std::string(kept), false};
  std::string result;
  result.reserve(kept.size() + text.size() - fenceOffset);
  result.append(kept).append(text.substr(fenceOffset));
  return {std::move(result), true};
}

size_t finishedBlocksEnd(std::string_view markdown) {
  Lines lines = splitLines(markdown);
  scanFences(lines);
  size_t end = 0;
  bool openMath = false;
  // While an HTML block that may hold blank lines is open, what closes it.
  std::string_view htmlCloser;
  for (size_t i = 0; i < lines.size(); i++) {
    const Line &line = lines[i];
    if (line.code)
      continue;
    std::string_view body = stripQuotes(line.text).body;
    if (!htmlCloser.empty()) {
      if (containsIgnoringCase(body, htmlCloser))
        htmlCloser = {};
      continue;
    }
    if (std::string_view closer = htmlBlockCloser(body); !closer.empty()) {
      if (!containsIgnoringCase(body.substr(body.find('<') + 2), closer))
        htmlCloser = closer;
      continue;
    }
    bool startsBlock =
        i > 0 && !openMath && isBlank(lines[i - 1].text) && !lines[i - 1].code && startsTopLevelBlock(line.text);
    // A line still arriving can start the tail once its first character rules
    // out a fence, `$$` and HTML, the kinds a later character could still make.
    char first = startsBlock ? line.text[0] : 0;
    if (startsBlock && (i + 1 < lines.size() || (first != '`' && first != '~' && first != '$')))
      end = line.offset;
    if (trim(body) == "$$")
      openMath = !openMath;
  }
  return end;
}

StreamingBlockMode streamingBlockModeFromName(const std::string &name) {
  return name == "hidden" ? StreamingBlockMode::Hidden : StreamingBlockMode::Progressive;
}

} // namespace Markdown
