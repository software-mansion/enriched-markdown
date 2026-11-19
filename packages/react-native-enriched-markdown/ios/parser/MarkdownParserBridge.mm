#include "AstOverlay.hpp"
#include "DocumentStore.hpp"
#import "ENRMLinkRegexConfig.h"
#import "ENRMMarkdownParser.h"
#import "ENRMUTF8.h"
#import "MarkdownASTNode.h"
#include "MarkdownASTNode.hpp"
#include "TextLinkRecognizer.hpp"
#include <algorithm>
#include <memory>
#include <mutex>
#include <unordered_set>
#include <vector>

// Copies the shared C++ tree into Objective-C nodes, with the overlay's slot ids,
// image ids and recognized links applied on the way; the C++ tree is not touched.
static MarkdownASTNode *convertCppASTToObjC(const Markdown::MarkdownASTNode &cppNode,
                                            const Markdown::AstOverlay &overlay)
{
  // Convert C++ NodeType enum to Objective-C MarkdownNodeType
  MarkdownNodeType objcType;
  switch (cppNode.type) {
    case Markdown::NodeType::Document:
      objcType = MarkdownNodeTypeDocument;
      break;
    case Markdown::NodeType::Paragraph:
      objcType = MarkdownNodeTypeParagraph;
      break;
    case Markdown::NodeType::Text:
      objcType = MarkdownNodeTypeText;
      break;
    case Markdown::NodeType::Link:
      objcType = MarkdownNodeTypeLink;
      break;
    case Markdown::NodeType::Heading:
      objcType = MarkdownNodeTypeHeading;
      break;
    case Markdown::NodeType::LineBreak:
      objcType = MarkdownNodeTypeLineBreak;
      break;
    case Markdown::NodeType::Strong:
      objcType = MarkdownNodeTypeStrong;
      break;
    case Markdown::NodeType::Emphasis:
      objcType = MarkdownNodeTypeEmphasis;
      break;
    case Markdown::NodeType::Strikethrough:
      objcType = MarkdownNodeTypeStrikethrough;
      break;
    case Markdown::NodeType::Underline:
      objcType = MarkdownNodeTypeUnderline;
      break;
    case Markdown::NodeType::Code:
      objcType = MarkdownNodeTypeCode;
      break;
    case Markdown::NodeType::Image:
      objcType = MarkdownNodeTypeImage;
      break;
    case Markdown::NodeType::Blockquote:
      objcType = MarkdownNodeTypeBlockquote;
      break;
    case Markdown::NodeType::UnorderedList:
      objcType = MarkdownNodeTypeUnorderedList;
      break;
    case Markdown::NodeType::OrderedList:
      objcType = MarkdownNodeTypeOrderedList;
      break;
    case Markdown::NodeType::ListItem:
      objcType = MarkdownNodeTypeListItem;
      break;
    case Markdown::NodeType::CodeBlock:
      objcType = MarkdownNodeTypeCodeBlock;
      break;
    case Markdown::NodeType::ThematicBreak:
      objcType = MarkdownNodeTypeThematicBreak;
      break;
    case Markdown::NodeType::Table:
      objcType = MarkdownNodeTypeTable;
      break;
    case Markdown::NodeType::TableHead:
      objcType = MarkdownNodeTypeTableHead;
      break;
    case Markdown::NodeType::TableBody:
      objcType = MarkdownNodeTypeTableBody;
      break;
    case Markdown::NodeType::TableRow:
      objcType = MarkdownNodeTypeTableRow;
      break;
    case Markdown::NodeType::TableHeaderCell:
      objcType = MarkdownNodeTypeTableHeaderCell;
      break;
    case Markdown::NodeType::TableCell:
      objcType = MarkdownNodeTypeTableCell;
      break;
    case Markdown::NodeType::LatexMathInline:
      objcType = MarkdownNodeTypeLatexMathInline;
      break;
    case Markdown::NodeType::LatexMathDisplay:
      objcType = MarkdownNodeTypeLatexMathDisplay;
      break;
    case Markdown::NodeType::Spoiler:
      objcType = MarkdownNodeTypeSpoiler;
      break;
    case Markdown::NodeType::Superscript:
      objcType = MarkdownNodeTypeSuperscript;
      break;
    case Markdown::NodeType::Subscript:
      objcType = MarkdownNodeTypeSubscript;
      break;
    case Markdown::NodeType::Highlight:
      objcType = MarkdownNodeTypeHighlight;
      break;
    case Markdown::NodeType::SoftBreak:
      objcType = MarkdownNodeTypeSoftBreak;
      break;
    case Markdown::NodeType::BlankLine:
      objcType = MarkdownNodeTypeBlankLine;
      break;
    case Markdown::NodeType::Admonition:
      objcType = MarkdownNodeTypeAdmonition;
      break;
    case Markdown::NodeType::Video:
      objcType = MarkdownNodeTypeVideo;
      break;
  }

  MarkdownASTNode *objcNode = [[MarkdownASTNode alloc] initWithType:objcType];

  if (!cppNode.content.empty()) {
    objcNode.content = ENRMStringFromUTF8(cppNode.content);
  }
  for (const auto &[key, value] : cppNode.attributes) {
    [objcNode setAttribute:ENRMStringFromUTF8(key) value:ENRMStringFromUTF8(value)];
  }
  overlay.forEachAttribute(cppNode, [&](const char *key, const std::string &value) {
    [objcNode setAttribute:@(key) value:ENRMStringFromUTF8(value)];
  });
  overlay.forEachChild(cppNode, [&](const std::shared_ptr<Markdown::MarkdownASTNode> &child) {
    [objcNode addChild:convertCppASTToObjC(*child, overlay)];
  });
  return objcNode;
}

// Host matchers for the core recognizer: NSRanges are UTF-16 units, which is what the core expects.
static Markdown::TextLinkMatchers ENRMTextLinkMatchers(ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex)
{
  Markdown::TextLinkMatchers matchers;
  NSRegularExpression *text = textRegex.parsedRegex;
  if (text) {
    matchers.text = [text](const std::vector<std::string_view> &runs) {
      std::vector<std::vector<Markdown::TextRange>> all;
      all.reserve(runs.size());
      for (std::string_view run : runs) {
        NSString *string = ENRMStringFromUTF8(run);
        std::vector<Markdown::TextRange> ranges;
        for (NSTextCheckingResult *match in [text matchesInString:string
                                                          options:0
                                                            range:NSMakeRange(0, string.length)]) {
          if (match.range.length > 0)
            ranges.push_back({match.range.location, NSMaxRange(match.range)});
        }
        all.push_back(std::move(ranges));
      }
      return all;
    };
  }
  NSRegularExpression *code = codeRegex.parsedWholeSpanRegex;
  if (code) {
    matchers.inlineCode = [code](const std::vector<std::string_view> &spans) {
      std::vector<uint8_t> matched;
      matched.reserve(spans.size());
      for (std::string_view span : spans) {
        NSString *string = ENRMStringFromUTF8(span);
        NSRange whole = NSMakeRange(0, string.length);
        NSTextCheckingResult *match = [code firstMatchInString:string options:0 range:whole];
        matched.push_back(match != nil && NSEqualRanges(match.range, whole));
      }
      return matched;
    };
  }
  return matchers;
}

MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM,
                                            ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex);
MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM,
                                            ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex,
                                            NSSet<NSString *> *activeBlockSlotIds, BOOL annotateImages);

MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM)
{
  return parseMarkdownWithCppParser(markdown, flags, isGFM, nil, nil);
}

MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM,
                                            ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex)
{
  return parseMarkdownWithCppParser(markdown, flags, isGFM, textRegex, codeRegex, nil, NO);
}

Markdown::Md4cFlags ENRMCoreMd4cFlags(ENRMMd4cFlags *flags)
{
  Markdown::Md4cFlags cppFlags;
  cppFlags.underline = flags.underline;
  cppFlags.latexMath = flags.latexMath;
  cppFlags.superscript = flags.superscript;
  cppFlags.subscript = flags.subscript;
  cppFlags.strikethrough = flags.strikethrough;
  cppFlags.highlight = flags.highlight;
  cppFlags.hardSoftBreaks = flags.hardSoftBreaks;
  cppFlags.preserveBlankLines = flags.preserveBlankLines;
  cppFlags.admonitions = flags.admonitions;
  return cppFlags;
}

static BOOL ENRMSameRegex(ENRMLinkRegexConfig *a, ENRMLinkRegexConfig *b)
{
  return a == b || [a isEqualToConfig:b];
}

namespace {

// The render, the view-free measurement and a nested quote's static measure
// convert the same shared document one after another on different threads; the
// last few conversions are kept so a streaming tick converts once.
struct ENRMConversion {
  std::shared_ptr<const Markdown::ParsedDocument> document;
  ENRMLinkRegexConfig *textRegex;
  ENRMLinkRegexConfig *codeRegex;
  std::unordered_set<std::string> slotIds;
  BOOL annotateImages;
  MarkdownASTNode *node;

  bool sameOptions(const ENRMConversion &other) const
  {
    return ENRMSameRegex(textRegex, other.textRegex) && ENRMSameRegex(codeRegex, other.codeRegex) &&
           annotateImages == other.annotateImages;
  }

  bool matches(const ENRMConversion &other) const
  {
    return document == other.document && sameOptions(other) && slotIds == other.slotIds;
  }

  // How many of the document's first blocks are the very nodes `other` converted, with the same
  // slots: a stream's finished blocks keep their nodes from one update to the next (DocumentStore).
  size_t sharedBlocks(const ENRMConversion &other) const
  {
    if (!sameOptions(other) || other.node.children.count != other.document->ast->children.size()) {
      return 0;
    }
    return Markdown::sharedLeadingBlocks(*document, *other.document, slotIds, other.slotIds);
  }
};

} // namespace

MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM,
                                            ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex,
                                            NSSet<NSString *> *activeBlockSlotIds, BOOL annotateImages)
{
  static std::mutex mutex;
  static std::vector<ENRMConversion> recent;
  // Render, measurement and a nested quote of one document, and the previous state of a stream.
  static const size_t kRecentConversions = 4;

  // Slots and image sources are GitHub-flavor features (the CommonMark host lays
  // nothing out for them).
  std::unordered_set<std::string> slotIds;
  if (isGFM) {
    for (NSString *slotId in activeBlockSlotIds) {
      slotIds.insert(ENRMUTF8String(slotId));
    }
  }
  ENRMConversion request{
      Markdown::DocumentStore::shared().parse(ENRMUTF8String(markdown), ENRMCoreMd4cFlags(flags), isGFM),
      textRegex,
      codeRegex,
      std::move(slotIds),
      isGFM && annotateImages,
      nil};
  if (!request.document->ast) {
    return [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  }
  // The blocks a recent conversion already holds are taken from it; only the rest is converted.
  NSArray<MarkdownASTNode *> *converted = nil;
  size_t shared = 0;
  {
    std::lock_guard<std::mutex> lock(mutex);
    for (auto entry = recent.begin(); entry != recent.end(); ++entry) {
      if (entry->matches(request)) {
        // Kept in front while it is in use, so a stream's next update still finds it.
        std::rotate(recent.begin(), entry, entry + 1);
        return recent.front().node;
      }
    }
    for (const auto &entry : recent) {
      size_t blocks = request.sharedBlocks(entry);
      if (blocks > shared) {
        shared = blocks;
        converted = entry.node.children;
      }
    }
  }

  Markdown::MarkdownASTNode added(Markdown::NodeType::Document);
  const auto &blocks = request.document->ast->children;
  added.children.assign(blocks.begin() + static_cast<std::ptrdiff_t>(shared), blocks.end());

  Markdown::TextLinkReplacements links;
  if (textRegex || codeRegex) {
    links = Markdown::recognizeTextLinks(added, ENRMTextLinkMatchers(textRegex, codeRegex));
  }
  Markdown::AstOverlay overlay(*request.document, request.slotIds, request.annotateImages, std::move(links));
  request.node = convertCppASTToObjC(added, overlay);
  if (shared > 0) {
    NSMutableArray<MarkdownASTNode *> *children = request.node.children;
    [children replaceObjectsInRange:NSMakeRange(0, 0) withObjectsFromArray:converted range:NSMakeRange(0, shared)];
  }

  std::lock_guard<std::mutex> lock(mutex);
  for (const auto &entry : recent) {
    if (entry.matches(request)) {
      return entry.node; // another thread converted it meanwhile
    }
  }
  recent.insert(recent.begin(), request);
  if (recent.size() > kRecentConversions) {
    recent.pop_back();
  }
  return request.node;
}
