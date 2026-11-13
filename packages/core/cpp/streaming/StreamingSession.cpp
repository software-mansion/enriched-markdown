#include "StreamingSession.hpp"
#include "TextScan.hpp"
#include <atomic>

namespace Markdown {

namespace {

constexpr size_t npos = std::string_view::npos;

struct Cut {
  size_t offset = npos;
  bool continuesList = false;
};

struct OpenFence {
  size_t start = npos;
  char character = 0;
  size_t length = 0;
};

struct Scan {
  Cut lastCut;
  Cut lastBlockCut;
  OpenFence openFence;
  bool hasLinkReferenceDefinition = false;

  void cut(size_t offset, bool continuingList) {
    lastCut = {offset, continuingList};
    if (!continuingList)
      lastBlockCut = lastCut;
  }
};

struct FenceMarker {
  char character = 0;
  size_t length = 0;
  bool infoIsBlank = false;
  bool isTopLevel = false;

  bool closes(const FenceMarker &opener) const {
    return character == opener.character && length >= opener.length && infoIsBlank;
  }
};

bool isSpaceOrTab(char c) {
  return c == ' ' || c == '\t';
}

bool isDigit(char c) {
  return c >= '0' && c <= '9';
}

size_t skipIndentAndBars(std::string_view line, size_t i) {
  while (i < line.size() && (isSpaceOrTab(line[i]) || line[i] == '>'))
    ++i;
  return i;
}

// The index after "-", "*", "+", "1." or "1)" and the whitespace that must follow, or npos.
size_t listMarkerEnd(std::string_view line, size_t i) {
  size_t j = i;
  if (j < line.size() && (line[j] == '-' || line[j] == '*' || line[j] == '+')) {
    ++j;
  } else {
    while (j < line.size() && isDigit(line[j]))
      ++j;
    if (j == i || j >= line.size() || (line[j] != '.' && line[j] != ')'))
      return npos;
    ++j;
  }
  if (j >= line.size() || !isSpaceOrTab(line[j]))
    return npos;
  while (j < line.size() && isSpaceOrTab(line[j]))
    ++j;
  return j;
}

bool parseFenceMarker(std::string_view line, FenceMarker &marker) {
  size_t i = skipIndentAndBars(line, 0);
  for (size_t j = listMarkerEnd(line, i); j != npos; j = listMarkerEnd(line, i))
    i = skipIndentAndBars(line, j);
  if (i >= line.size() || (line[i] != '`' && line[i] != '~'))
    return false;
  size_t end = i;
  while (end < line.size() && line[end] == line[i])
    ++end;
  if (end - i < 3)
    return false;
  std::string_view info = line.substr(end);
  if (line[i] == '`' && info.find('`') != npos)
    return false;
  marker = {line[i], end - i, isBlank(info), i == 0};
  return true;
}

bool isThematicBreak(std::string_view line) {
  char mark = 0;
  size_t count = 0;
  for (char c : line) {
    if (isSpaceOrTab(c) || c == '\r')
      continue;
    if (mark == 0) {
      if (c != '-' && c != '*' && c != '_')
        return false;
      mark = c;
    } else if (c != mark) {
      return false;
    }
    ++count;
  }
  return count >= 3;
}

// The marker byte of a list item starting at column 0 ("-", "*", "+", "." or ")"), or 0.
char topLevelListMarker(std::string_view line) {
  if (line.empty() || isThematicBreak(line) || listMarkerEnd(line, 0) == npos)
    return 0;
  if (line[0] == '-' || line[0] == '*' || line[0] == '+')
    return line[0];
  size_t digits = 0;
  while (isDigit(line[digits]))
    ++digits;
  return digits <= 9 ? line[digits] : 0;
}

bool startsIndented(std::string_view line) {
  return !line.empty() && isSpaceOrTab(line[0]);
}

bool canStartIndependentBlock(std::string_view line) {
  if (line.empty())
    return false;
  char c = line[0];
  return !isSpaceOrTab(c) && c != '\r' && c != '-' && c != '*' && c != '+' && !isDigit(c) && c != '[' && c != '<';
}

bool isLinkReferenceDefinition(std::string_view line) {
  size_t i = 0;
  while (i < line.size() && i < 3 && line[i] == ' ')
    ++i;
  if (i >= line.size() || line[i] != '[')
    return false;
  size_t close = line.find(']', i);
  return close != npos && close > i + 1 && close + 1 < line.size() && line[close + 1] == ':';
}

bool startsRawHTML(std::string_view line) {
  static const char *const kOpeners[] = {"<!--", "<?", "<![CDATA[", "<pre", "<script", "<style", "<textarea"};
  size_t i = 0;
  while (i < line.size() && line[i] == ' ')
    ++i;
  std::string_view content = line.substr(i);
  if (content.empty() || content[0] != '<')
    return false;
  std::string lowered;
  for (char c : content.substr(0, 9))
    lowered.push_back(c >= 'A' && c <= 'Z' ? static_cast<char>(c + 32) : c);
  for (const char *opener : kOpeners) {
    if (startsWith(lowered, opener))
      return true;
  }
  return false;
}

struct LineState {
  char openList = 0;
  bool previousLineBlank = false;
  bool insideHTMLBlock = false;
};

void visitContent(std::string_view line, size_t lineStart, LineState &state, Scan &result) {
  if (line[0] == '<') {
    state.insideHTMLBlock = true;
    state.openList = 0;
  } else if (char marker = topLevelListMarker(line)) {
    if (marker == state.openList) {
      if (lineStart > 0)
        result.cut(lineStart, true);
    } else {
      state.openList = marker;
      if (lineStart > 0 && state.previousLineBlank)
        result.cut(lineStart, false);
    }
  } else if (!startsIndented(line)) {
    if (state.previousLineBlank)
      state.openList = 0;
    if (lineStart > 0 && state.previousLineBlank && canStartIndependentBlock(line))
      result.cut(lineStart, false);
  }
}

void visit(std::string_view line, size_t lineStart, LineState &state, Scan &result) {
  bool blank = isBlank(line);
  if (blank)
    state.insideHTMLBlock = false;
  else if (!state.insideHTMLBlock)
    visitContent(line, lineStart, state, result);
  state.previousLineBlank = blank;
}

Scan scanBlocks(std::string_view text) {
  Scan result;
  FenceMarker fence;
  bool inFence = false;
  size_t fenceStart = 0;
  LineState state;
  size_t lineStart = 0;
  while (lineStart < text.size()) {
    size_t lineEnd = text.find('\n', lineStart);
    if (lineEnd == npos)
      lineEnd = text.size();
    std::string_view line = text.substr(lineStart, lineEnd - lineStart);
    FenceMarker marker;
    if (inFence) {
      if (parseFenceMarker(line, marker) && marker.closes(fence))
        inFence = false;
      state.previousLineBlank = false;
      lineStart = lineEnd + 1;
      continue;
    }
    if (isLinkReferenceDefinition(line))
      result.hasLinkReferenceDefinition = true;
    if (startsRawHTML(line))
      return result;
    visit(line, lineStart, state, result);
    if (parseFenceMarker(line, marker)) {
      inFence = true;
      fence = marker;
      fenceStart = lineStart;
    }
    lineStart = lineEnd + 1;
  }
  if (inFence && fence.isTopLevel)
    result.openFence = {fenceStart, fence.character, fence.length};
  return result;
}

std::string_view droppingPartialCloser(std::string_view body, const OpenFence &fence) {
  size_t lineStart = body.rfind('\n');
  lineStart = lineStart == npos ? 0 : lineStart + 1;
  std::string_view line = body.substr(lineStart);
  while (!line.empty() && (isSpaceOrTab(line.front()) || line.front() == '\r'))
    line.remove_prefix(1);
  while (!line.empty() && (isSpaceOrTab(line.back()) || line.back() == '\r'))
    line.remove_suffix(1);
  if (line.empty() || line.size() >= fence.length || line.find_first_not_of(fence.character) != npos)
    return body;
  return body.substr(0, lineStart);
}

struct Tail {
  std::string markdown;
  bool hasContent = false;
  bool endsInsideOpenCodeFence = false;
  size_t codeBodyStart = npos;
};

Tail makeTail(std::string_view unfinished, const StreamingFilterOptions &filter, const RepairOptions &repair) {
  StreamingFilterResult filtered = renderableMarkdownForStreaming(std::string(unfinished), filter);
  Tail tail;
  tail.endsInsideOpenCodeFence = filtered.endsInsideOpenCodeFence;
  OpenFence fence;
  if (filtered.endsInsideOpenCodeFence)
    fence = scanBlocks(filtered.markdown).openFence;
  size_t openerEnd = fence.start == npos ? npos : filtered.markdown.find('\n', fence.start);
  if (openerEnd != npos) {
    size_t bodyStart = openerEnd + 1;
    std::string_view body = droppingPartialCloser(std::string_view(filtered.markdown).substr(bodyStart), fence);
    tail.markdown = filtered.markdown.substr(0, bodyStart);
    tail.markdown.append(body);
    tail.codeBodyStart = bodyStart;
  } else {
    tail.markdown = repairInlineMarkdown(filtered.markdown, repair);
  }
  std::string_view text = tail.markdown;
  tail.hasContent = !isBlank(text);
  if (tail.hasContent && fence.start != npos) {
    size_t bodyStart = openerEnd == npos ? text.size() : openerEnd + 1;
    tail.hasContent = !isBlank(text.substr(0, fence.start)) || !isBlank(text.substr(bodyStart));
  }
  return tail;
}

uint64_t nextLineage() {
  static std::atomic<uint64_t> counter{0};
  return ++counter;
}

} // namespace

StreamingSession::StreamingSession(StreamingSessionOptions options)
    : options_(std::move(options)), lineage_(nextLineage()), rendersWhole_(!options_.cutBlocks) {}

StreamingUpdate StreamingSession::update(std::string_view markdown, const StreamingFilterOptions &filter) {
  return update(markdown, filter, true);
}

StreamingUpdate StreamingSession::restartOpenList(std::string_view markdown, const StreamingFilterOptions &filter) {
  if (listAnchor_ != npos) {
    frozen_.resize(listAnchor_);
    continuesList_ = false;
    listAnchor_ = npos;
  }
  return update(markdown, filter, false);
}

void StreamingSession::reset() {
  lineage_ = nextLineage();
  frozen_.clear();
  continuesList_ = false;
  listAnchor_ = npos;
}

StreamingUpdate StreamingSession::update(std::string_view markdown, const StreamingFilterOptions &filter,
                                         bool cuttingLists) {
  if (!startsWith(markdown, frozen_))
    reset();
  std::string_view rest = markdown.substr(frozen_.size());
  Scan scan = scanBlocks(rest);
  if (scan.hasLinkReferenceDefinition && !rendersWhole_) {
    rendersWhole_ = true;
    reset();
    rest = markdown;
    scan = scanBlocks(rest);
  }
  Cut cut = rendersWhole_ ? Cut{} : cuttingLists ? scan.lastCut : scan.lastBlockCut;
  size_t cutOffset = cut.offset == npos ? 0 : cut.offset;
  Tail tail = makeTail(rest.substr(cutOffset), filter, options_.repair);
  if (cutOffset > 0 && !tail.hasContent) {
    cut = {};
    cutOffset = 0;
    tail = makeTail(rest, filter, options_.repair);
  }

  StreamingUpdate result;
  result.lineage = lineage_;
  result.frozenBytes = frozen_.size();
  result.finishedBytes = cutOffset;
  result.finishedContinuesList = cutOffset > 0 && continuesList_;
  result.finishedContinuedByTail = cutOffset > 0 && cut.continuesList;
  result.tail = std::move(tail.markdown);
  result.tailContinuesList = cutOffset > 0 ? cut.continuesList : continuesList_;
  result.tailEndsInsideOpenCodeFence = tail.endsInsideOpenCodeFence;
  result.tailCodeBodyStart = tail.codeBodyStart;

  if (cutOffset > 0) {
    if (!cut.continuesList)
      listAnchor_ = npos;
    else if (listAnchor_ == npos)
      listAnchor_ = frozen_.size();
    continuesList_ = cut.continuesList;
    frozen_.append(rest.data(), cutOffset);
  }
  return result;
}

} // namespace Markdown
