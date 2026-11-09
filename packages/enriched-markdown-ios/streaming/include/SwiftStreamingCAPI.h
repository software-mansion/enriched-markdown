#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct EMStreamingSession EMStreamingSession;

typedef struct {
  uint64_t lineage;
  size_t frozenBytes;
  size_t finishedBytes;
  int finishedContinuesList;
  int finishedContinuedByTail;
  char *tail;               // released by em_streaming_update_release; NULL when the update failed
  size_t tailCodeBodyStart; // SIZE_MAX without an open top-level fence
  int tailContinuesList;
  int tailEndsInsideOpenCodeFence;
} EMStreamingUpdate;

EMStreamingSession *em_streaming_session_create(int highlight, int latexMath, int superscript, int subscript,
                                                int cutBlocks);
void em_streaming_session_release(EMStreamingSession *session);

void em_streaming_session_update(EMStreamingSession *session, const char *markdown, int hideTables, int hideCodeBlocks,
                                 int hideMedia, int restartOpenList, EMStreamingUpdate *update);
void em_streaming_update_release(EMStreamingUpdate *update);

#ifdef __cplusplus
}
#endif
