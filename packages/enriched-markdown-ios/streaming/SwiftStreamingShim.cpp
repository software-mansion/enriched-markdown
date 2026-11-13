#include "SwiftStreamingCAPI.h"

#include "StreamingSession.hpp"

#include <cstdlib>
#include <cstring>

struct EMStreamingSession {
  Markdown::StreamingSession session;
};

namespace {

Markdown::StreamingBlockMode mode(int hidden) {
  return hidden != 0 ? Markdown::StreamingBlockMode::Hidden : Markdown::StreamingBlockMode::Progressive;
}

void clear(EMStreamingUpdate *update) {
  *update = EMStreamingUpdate{};
  update->tailCodeBodyStart = SIZE_MAX;
}

} // namespace

extern "C" {

EMStreamingSession *em_streaming_session_create(int highlight, int latexMath, int superscript, int subscript,
                                                int cutBlocks) {
  Markdown::StreamingSessionOptions options;
  options.repair.linkMode = Markdown::LinkMode::TextOnly;
  options.repair.inlineMath = latexMath != 0;
  options.repair.displayMath = latexMath != 0;
  options.repair.highlight = highlight != 0;
  options.repair.superscript = superscript != 0;
  options.repair.subscript = subscript != 0;
  options.repair.withholdIncomplete = true;
  options.repair.withholdMath = true;
  options.cutBlocks = cutBlocks != 0;
  return new EMStreamingSession{Markdown::StreamingSession(options)};
}

void em_streaming_session_release(EMStreamingSession *session) {
  delete session;
}

void em_streaming_session_update(EMStreamingSession *session, const char *markdown, int hideTables, int hideCodeBlocks,
                                 int hideMedia, int restartOpenList, EMStreamingUpdate *update) {
  if (!update) {
    return;
  }
  clear(update);
  if (!session || !markdown) {
    return;
  }
  Markdown::StreamingFilterOptions filter;
  filter.tableMode = mode(hideTables);
  filter.codeBlockMode = mode(hideCodeBlocks);
  filter.mediaMode = mode(hideMedia);
  try {
    Markdown::StreamingUpdate result = restartOpenList != 0 ? session->session.restartOpenList(markdown, filter)
                                                            : session->session.update(markdown, filter);
    update->lineage = result.lineage;
    update->frozenBytes = result.frozenBytes;
    update->finishedBytes = result.finishedBytes;
    update->finishedContinuesList = result.finishedContinuesList ? 1 : 0;
    update->finishedContinuedByTail = result.finishedContinuedByTail ? 1 : 0;
    update->tail = strdup(result.tail.c_str());
    update->tailCodeBodyStart = result.tailCodeBodyStart == std::string::npos ? SIZE_MAX : result.tailCodeBodyStart;
    update->tailContinuesList = result.tailContinuesList ? 1 : 0;
    update->tailEndsInsideOpenCodeFence = result.tailEndsInsideOpenCodeFence ? 1 : 0;
  } catch (...) {
    clear(update);
  }
}

void em_streaming_update_release(EMStreamingUpdate *update) {
  if (update) {
    std::free(update->tail);
    update->tail = nullptr;
  }
}

} // extern "C"
