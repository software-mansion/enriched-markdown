#include "../../common/ENRMMarkdownStreams.h"
#import <XCTest/XCTest.h>

using facebook::react::ENRMMarkdownStreams;
using facebook::react::ENRMResolveStreamedMarkdown;

// The fields the resolver reads, as codegen generates them on the components' props.
struct ENRMBaseProps {
  virtual ~ENRMBaseProps() = default;
};
struct ENRMStreamedProps : ENRMBaseProps {
  std::string markdown;
  int streamId = 0;
  int streamLength = 0;
};
using ENRMSharedProps = std::shared_ptr<const ENRMBaseProps>;

static ENRMSharedProps ENRMStreamProps(int streamId, int length, std::string markdown)
{
  auto props = std::make_shared<ENRMStreamedProps>();
  props->streamId = streamId;
  props->streamLength = length;
  props->markdown = std::move(markdown);
  return props;
}

static std::string ENRMResolved(const ENRMSharedProps &source, const ENRMSharedProps &props)
{
  return static_cast<const ENRMStreamedProps &>(*ENRMResolveStreamedMarkdown<ENRMStreamedProps>(source, props))
      .markdown;
}

@interface ENRMMarkdownStreamsTests : XCTestCase
@end

@implementation ENRMMarkdownStreamsTests

- (void)testAStreamsPrefixIsTheSameTextAfterItGrows
{
  auto &streams = ENRMMarkdownStreams::shared();
  int id = streams.create("# Title");
  XCTAssertEqual(streams.append(id, "\n\nOne"), 12u);
  std::string earlier = streams.prefix(id, 7);
  streams.append(id, " two");
  XCTAssertEqual(streams.prefix(id, 7), earlier);
  XCTAssertEqual(streams.prefix(id, 100), "# Title\n\nOne two");
  streams.dispose(id);
  XCTAssertEqual(streams.prefix(id, 7), "");
  XCTAssertEqual(streams.append(id, "late"), 0u);
}

- (void)testPropsBoundToAStreamTakeItsTextAsMarkdown
{
  auto &streams = ENRMMarkdownStreams::shared();
  int id = streams.create("Hello world");
  XCTAssertEqual(ENRMResolved(nullptr, ENRMStreamProps(id, 5, "placeholder")), "Hello");
  // Without a stream, markdown is what JS sent.
  XCTAssertEqual(ENRMResolved(nullptr, ENRMStreamProps(0, 0, "plain")), "plain");
  streams.dispose(id);
}

- (void)testAnUnchangedStreamLengthKeepsTheCopiedText
{
  auto &streams = ENRMMarkdownStreams::shared();
  int id = streams.create("Hello world");
  auto source = ENRMStreamProps(id, 5, "Hello");
  XCTAssertEqual(ENRMResolved(source, ENRMStreamProps(id, 11, "Hello")), "Hello world");
  streams.dispose(id);
  // Cloned for another prop: the text is the source's, not read again (the stream is gone).
  XCTAssertEqual(ENRMResolved(source, ENRMStreamProps(id, 5, "Hello")), "Hello");
  // A full prop set brought the placeholder back, even one as long as the text.
  XCTAssertEqual(ENRMResolved(source, ENRMStreamProps(id, 5, "#s:12")), "Hello");
}

@end
