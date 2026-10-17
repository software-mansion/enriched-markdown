#include "BlockSlots.hpp"
#import "ENRMLinkRegexConfig.h"
#import "ENRMMarkdownParser.h"
#include "MD4CParser.hpp"
#import "MarkdownASTNode.h"
#include "MarkdownASTNode.hpp"
#include "TextLinkRecognizer.hpp"
#import <React/RCTLog.h>

// Convert C++ AST node to Objective-C AST node
static MarkdownASTNode *convertCppASTToObjC(std::shared_ptr<Markdown::MarkdownASTNode> cppNode)
{
  if (!cppNode) {
    return [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  }

  // Convert C++ NodeType enum to Objective-C MarkdownNodeType
  MarkdownNodeType objcType;
  switch (cppNode->type) {
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

  // Convert content
  if (!cppNode->content.empty()) {
    objcNode.content = [NSString stringWithUTF8String:cppNode->content.c_str()];
  }

  // Convert attributes
  for (const auto &[key, value] : cppNode->attributes) {
    NSString *objcKey = [NSString stringWithUTF8String:key.c_str()];
    NSString *objcValue = [NSString stringWithUTF8String:value.c_str()];
    [objcNode setAttribute:objcKey value:objcValue];
  }

  // Convert children recursively
  for (const auto &child : cppNode->children) {
    MarkdownASTNode *objcChild = convertCppASTToObjC(child);
    [objcNode addChild:objcChild];
  }

  return objcNode;
}

static NSString *ENRMStringFromUTF8(std::string_view utf8)
{
  return [[NSString alloc] initWithBytes:utf8.data() length:utf8.size() encoding:NSUTF8StringEncoding] ?: @"";
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

// Parses with the C++ parser, runs text link recognition and the block slot /
// image occurrence annotation in the core, and converts to the Objective-C AST.
static MarkdownASTNode *parseMarkdownUncached(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM,
                                              ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex,
                                              NSSet<NSString *> *activeBlockSlotIds, BOOL annotateImages)
{
  if (markdown.length == 0) {
    return [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  }

  // Convert NSString to std::string
  const char *utf8String = [markdown UTF8String];
  if (!utf8String) {
    RCTLogError(@"MarkdownParserBridge: Failed to convert markdown to UTF-8");
    return [[MarkdownASTNode alloc] initWithType:MarkdownNodeTypeDocument];
  }

  std::string cppMarkdown(utf8String);

  // Convert Objective-C flags to C++ flags
  Markdown::Md4cFlags cppFlags;
  cppFlags.underline = flags.underline;
  cppFlags.latexMath = flags.latexMath;
  cppFlags.superscript = flags.superscript;
  cppFlags.subscript = flags.subscript;
  cppFlags.highlight = flags.highlight;
  cppFlags.hardSoftBreaks = flags.hardSoftBreaks;
  cppFlags.preserveBlankLines = flags.preserveBlankLines;
  cppFlags.admonitions = flags.admonitions;

  Markdown::MD4CParser parser;
  auto cppAST = parser.parse(cppMarkdown, cppFlags, isGFM);
  // Slots and image sources are GFM features (the CommonMark host lays nothing
  // out for them); one walk stamps both. It runs before text-link recognition,
  // which the JS collector never runs, so both count the same slots.
  if (cppAST && isGFM && (activeBlockSlotIds.count > 0 || annotateImages)) {
    std::unordered_set<std::string> ids;
    for (NSString *slotId in activeBlockSlotIds) {
      ids.insert(std::string(slotId.UTF8String ?: ""));
    }
    Markdown::annotate(*cppAST, ids, annotateImages);
  }
  if (cppAST && (textRegex || codeRegex)) {
    Markdown::recognizeTextLinks(*cppAST, ENRMTextLinkMatchers(textRegex, codeRegex));
  }

  // Convert C++ AST to Objective-C AST
  return convertCppASTToObjC(cppAST);
}

// The view's render, the view-free measurement and a nested quote's static
// measure parse the same document with the same options, one after the other and
// on different threads; the last few results are kept so a streaming tick parses
// once. Nothing mutates an AST after parsing, so sharing one is safe.
static NSString *ENRMParseCacheKey(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM, ENRMLinkRegexConfig *textRegex,
                                   ENRMLinkRegexConfig *codeRegex, NSSet<NSString *> *activeBlockSlotIds,
                                   BOOL annotateImages)
{
  NSMutableString *key = [NSMutableString stringWithCapacity:markdown.length + 128];
  [key appendFormat:@"%d%d%d%d%d%d%d%d|%d|", flags.underline, flags.latexMath, flags.superscript, flags.subscript,
                    flags.highlight, flags.hardSoftBreaks, flags.preserveBlankLines, flags.admonitions, isGFM];
  for (ENRMLinkRegexConfig *regex in @[ textRegex ?: (id)NSNull.null, codeRegex ?: (id)NSNull.null ]) {
    if ([regex isKindOfClass:[ENRMLinkRegexConfig class]]) {
      [key appendFormat:@"%d%d%d%d%@", regex.caseInsensitive, regex.dotAll, regex.isDisabled, regex.isDefault,
                        regex.pattern];
    }
    [key appendString:@"|"];
  }
  for (NSString *slotId in [activeBlockSlotIds.allObjects sortedArrayUsingSelector:@selector(compare:)]) {
    [key appendString:slotId];
    [key appendString:@","];
  }
  [key appendFormat:@"|%d|", annotateImages];
  [key appendString:markdown];
  return key;
}

MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags, BOOL isGFM,
                                            ENRMLinkRegexConfig *textRegex, ENRMLinkRegexConfig *codeRegex,
                                            NSSet<NSString *> *activeBlockSlotIds, BOOL annotateImages)
{
  static NSLock *lock;
  static NSMutableArray<NSString *> *keys;
  static NSMutableArray<MarkdownASTNode *> *nodes;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    lock = [[NSLock alloc] init];
    keys = [NSMutableArray array];
    nodes = [NSMutableArray array];
  });
  // Render, measure and a nested quote's static measure of one document.
  static const NSUInteger kRecentParses = 3;

  NSString *key = ENRMParseCacheKey(markdown, flags, isGFM, textRegex, codeRegex, activeBlockSlotIds, annotateImages);
  [lock lock];
  NSUInteger index = [keys indexOfObject:key];
  MarkdownASTNode *cached = index == NSNotFound ? nil : nodes[index];
  [lock unlock];
  if (cached) {
    return cached;
  }

  MarkdownASTNode *ast =
      parseMarkdownUncached(markdown, flags, isGFM, textRegex, codeRegex, activeBlockSlotIds, annotateImages);
  if (ast) {
    [lock lock];
    [keys insertObject:key atIndex:0];
    [nodes insertObject:ast atIndex:0];
    while (keys.count > kRecentParses) {
      [keys removeLastObject];
      [nodes removeLastObject];
    }
    [lock unlock];
  }
  return ast;
}
