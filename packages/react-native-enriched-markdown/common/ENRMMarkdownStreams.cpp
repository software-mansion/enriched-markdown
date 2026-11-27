#include "ENRMMarkdownStreams.h"

namespace facebook::react {

ENRMMarkdownStreams &ENRMMarkdownStreams::shared() {
  // Never destroyed: JS and UI threads may still read it while the process exits.
  static auto *streams = new ENRMMarkdownStreams();
  return *streams;
}

} // namespace facebook::react
