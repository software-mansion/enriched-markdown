#import "ENRMMarkdownParser.h"
#include "MD4CParser.hpp"
#import "MarkdownASTNode.h"
#include "MarkdownASTNode.hpp"
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

// Public function to parse markdown using C++ parser and convert to Objective-C AST
MarkdownASTNode *parseMarkdownWithCppParser(NSString *markdown, ENRMMd4cFlags *flags)
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

  Markdown::MD4CParser parser;
  auto cppAST = parser.parse(cppMarkdown, cppFlags);

  // Convert C++ AST to Objective-C AST
  return convertCppASTToObjC(cppAST);
}
