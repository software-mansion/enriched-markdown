#include "StreamingFilter.hpp"
#include "BlockKinds.hpp"
#include <vector>

namespace Markdown {

namespace {

using Lines = std::vector<std::string>;

Lines splitLines(const std::string &text) {
  Lines lines;
  size_t start = 0;
  while (true) {
    size_t end = text.find('\n', start);
    if (end == std::string::npos) {
      lines.push_back(text.substr(start));
      break;
    }
    lines.push_back(text.substr(start, end - start));
    start = end + 1;
  }
  return lines;
}

// Byte offset of each line's first character in the joined text.
std::vector<size_t> lineOffsets(const Lines &lines) {
  std::vector<size_t> offsets(lines.size());
  size_t offset = 0;
  for (size_t i = 0; i < lines.size(); i++) {
    offsets[i] = offset;
    offset += lines[i].size() + 1;
  }
  return offsets;
}

bool isSpace(char ch) {
  return ch == ' ' || ch == '\t' || ch == '\r' || ch == '\f' || ch == '\v';
}

std::string trim(const std::string &line) {
  size_t start = 0;
  while (start < line.size() && isSpace(line[start]))
    start++;
  size_t end = line.size();
  while (end > start && isSpace(line[end - 1]))
    end--;
  return line.substr(start, end - start);
}

bool lineIsBlank(const std::string &line) {
  for (char ch : line) {
    if (!isSpace(ch))
      return false;
  }
  return true;
}

int lastNonBlankLine(const Lines &lines) {
  for (int i = static_cast<int>(lines.size()) - 1; i >= 0; i--) {
    if (!lineIsBlank(lines[static_cast<size_t>(i)]))
      return i;
  }
  return -1;
}

// A trailing block is still arriving unless a blank line follows it, i.e. the
// document ends more than one newline after its last non-blank line.
bool trailingBlockIsOpen(const Lines &lines, int lastNonBlank) {
  return lastNonBlank != -1 && static_cast<size_t>(lastNonBlank) + 1 >= lines.size() - 1;
}

// ---- fenced code

struct FenceMarker {
  char ch = 0;
  size_t length = 0;
  std::string info;
};

bool parseFenceMarker(const std::string &line, FenceMarker &out) {
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
  std::string info = line.substr(i);
  if (ch == '`' && info.find('`') != std::string::npos)
    return false;
  out = {ch, run, info};
  return true;
}

int openCodeFenceLine(const Lines &lines) {
  int openIndex = -1;
  char openChar = 0;
  size_t openLength = 0;
  for (size_t i = 0; i < lines.size(); i++) {
    FenceMarker marker;
    bool isMarker = parseFenceMarker(lines[i], marker);
    if (openIndex == -1) {
      if (isMarker) {
        openIndex = static_cast<int>(i);
        openChar = marker.ch;
        openLength = marker.length;
      }
    } else if (isMarker && marker.ch == openChar && marker.length >= openLength && lineIsBlank(marker.info)) {
      openIndex = -1;
    }
  }
  return openIndex;
}

// ---- block math

std::string removePendingMathBlock(const std::string &markdown, const Lines &lines) {
  int unclosed = -1;
  for (size_t i = 0; i < lines.size(); i++) {
    if (trim(lines[i]) == "$$")
      unclosed = unclosed == -1 ? static_cast<int>(i) : -1;
  }
  if (unclosed == -1)
    return markdown;
  return markdown.substr(0, lineOffsets(lines)[static_cast<size_t>(unclosed)]);
}

// ---- tables

bool looksLikeTableRow(const std::string &line) {
  std::string trimmed = trim(line);
  return !trimmed.empty() && trimmed[0] == '|';
}

bool looksLikeTableSeparator(const std::string &line) {
  std::string trimmed = trim(line);
  if (trimmed.empty() || trimmed[0] != '|')
    return false;
  bool tripleDash = false;
  size_t dashRun = 0;
  for (char ch : trimmed) {
    if (ch == '-') {
      dashRun++;
      if (dashRun >= 3)
        tripleDash = true;
    } else {
      dashRun = 0;
      if (ch != '|' && ch != ':' && ch != ' ')
        return false;
    }
  }
  return tripleDash;
}

size_t pipeCount(const std::string &line) {
  size_t count = 0;
  for (char ch : line) {
    if (ch == '|')
      count++;
  }
  return count;
}

std::string removePendingTableBlock(const std::string &markdown, const Lines &lines, StreamingBlockMode mode) {
  int last = lastNonBlankLine(lines);
  if (!trailingBlockIsOpen(lines, last))
    return markdown;

  int blockStart = last;
  while (blockStart > 0 && !lineIsBlank(lines[static_cast<size_t>(blockStart) - 1]))
    blockStart--;
  for (int i = blockStart; i <= last; i++) {
    if (!looksLikeTableRow(lines[static_cast<size_t>(i)]))
      return markdown;
  }

  auto offsets = lineOffsets(lines);
  if (mode == StreamingBlockMode::Hidden)
    return markdown.substr(0, offsets[static_cast<size_t>(blockStart)]);

  int lineCount = last - blockStart + 1;
  if (lineCount < 2 || !looksLikeTableSeparator(lines[static_cast<size_t>(blockStart) + 1]))
    return markdown.substr(0, offsets[static_cast<size_t>(blockStart)]);
  if (lineCount > 2) {
    const std::string &lastRow = lines[static_cast<size_t>(last)];
    std::string lastTrimmed = trim(lastRow);
    const std::string &header = lines[static_cast<size_t>(blockStart)];
    if (lastTrimmed.back() != '|' || pipeCount(lastRow) < pipeCount(header))
      return markdown.substr(0, offsets[static_cast<size_t>(last)]);
  }
  return markdown;
}

// ---- media

// The line without the quote markers a nested image paragraph sits behind. Up
// to three spaces of indentation are stripped with them; four or more make the
// line indented code, which stays as it is so no classifier matches it.
std::string stripQuotePrefixes(const std::string &line) {
  size_t i = 0;
  size_t spaces = 0;
  while (i < line.size() && (line[i] == ' ' || line[i] == '>')) {
    if (line[i] == '>') {
      spaces = 0;
    } else if (++spaces > 3) {
      return line.substr(i - 3);
    }
    i++;
  }
  return line.substr(i);
}

bool isIndentedCode(const std::string &line) {
  std::string body = stripQuotePrefixes(line);
  return body.rfind("    ", 0) == 0 || body.rfind("\t", 0) == 0;
}

using MediaLine = BlockLineState;

// Whether the line is a block a slot can replace (one of kBlockKinds) and
// whether its syntax has closed.
MediaLine classifyMediaLine(const std::string &line) {
  std::string body = stripQuotePrefixes(line);
  for (const auto &kind : kBlockKinds) {
    MediaLine state = kind.lineState(body);
    if (state != MediaLine::None)
      return state;
  }
  return MediaLine::None;
}

// Where an inline image or link whose syntax is still open starts on the line
// (`![alt](https://` or `[label](ur`, or a `[label]` the `(` may still follow),
// or npos when the line ends cleanly. Escaped brackets and brackets inside code
// spans are prose.
size_t openInlineSyntaxStart(const std::string &line) {
  size_t bracket = line.rfind('[');
  while (bracket != std::string::npos &&
         (InlineSyntax::isEscaped(line, bracket) || InlineSyntax::insideCodeSpan(line, bracket))) {
    bracket = bracket == 0 ? std::string::npos : line.rfind('[', bracket - 1);
  }
  if (bracket == std::string::npos)
    return std::string::npos;
  if (InlineSyntax::state(line, bracket) != MediaLine::Open)
    return std::string::npos;
  // An escaped `!` is literal text; the link after it is still a link.
  bool image = bracket > 0 && line[bracket - 1] == '!' && !InlineSyntax::isEscaped(line, bracket - 1);
  return image ? bracket - 1 : bracket;
}

// `terminated` says another block (an open code fence) follows the text, which
// closes a trailing paragraph the way a blank line does.
std::string removePendingMediaBlock(const std::string &markdown, const Lines &lines, StreamingBlockMode mode,
                                    bool terminated) {
  int last = lastNonBlankLine(lines);
  if (!trailingBlockIsOpen(lines, last))
    return markdown;
  const std::string &line = lines[static_cast<size_t>(last)];
  size_t lineOffset = lineOffsets(lines)[static_cast<size_t>(last)];
  MediaLine state = classifyMediaLine(line);
  if (state == MediaLine::None) {
    // Not a block, but the paragraph may end in an image or link still being
    // typed: cut that syntax so it never shows as literal text. Indented code
    // is left alone.
    size_t open = terminated || isIndentedCode(line) ? std::string::npos : openInlineSyntaxStart(line);
    return open == std::string::npos ? markdown : markdown.substr(0, lineOffset + open);
  }
  if (state == MediaLine::Complete && (mode == StreamingBlockMode::Progressive || terminated))
    return markdown;
  return markdown.substr(0, lineOffset);
}

std::string removePendingBlocks(const std::string &markdown, const StreamingFilterOptions &options, bool terminated) {
  Lines lines = splitLines(markdown);
  std::string afterMath = removePendingMathBlock(markdown, lines);
  if (afterMath.size() != markdown.size())
    lines = splitLines(afterMath);
  std::string afterTable = removePendingTableBlock(afterMath, lines, options.tableMode);
  if (afterTable.size() != afterMath.size())
    lines = splitLines(afterTable);
  return removePendingMediaBlock(afterTable, lines, options.mediaMode, terminated);
}

} // namespace

StreamingFilterResult renderableMarkdownForStreaming(const std::string &markdown,
                                                     const StreamingFilterOptions &options) {
  Lines lines = splitLines(markdown);
  int openFence = openCodeFenceLine(lines);
  if (openFence == -1)
    return {removePendingBlocks(markdown, options, false), false};

  // The fence terminates whatever paragraph precedes it, shown or not.
  size_t fenceOffset = lineOffsets(lines)[static_cast<size_t>(openFence)];
  std::string head = removePendingBlocks(markdown.substr(0, fenceOffset), options, true);
  if (options.codeBlockMode == StreamingBlockMode::Hidden)
    return {head, false};
  return {head + markdown.substr(fenceOffset), true};
}

StreamingBlockMode streamingBlockModeFromName(const std::string &name) {
  return name == "hidden" ? StreamingBlockMode::Hidden : StreamingBlockMode::Progressive;
}

} // namespace Markdown
