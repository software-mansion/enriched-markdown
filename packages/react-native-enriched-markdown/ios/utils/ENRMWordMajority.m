#import "ENRMWordMajority.h"
#import "MarkdownASTNode.h"
#import "StyleConfig.h"

NSString *const ENRMProseDirectionKey = @"_enrmProseDirection";

static BOOL ENRMIsRTLLetter(UTF32Char c)
{
  return (c >= 0x0590 && c <= 0x08FF) || (c >= 0xFB1D && c <= 0xFDFF) || (c >= 0xFE70 && c <= 0xFEFF) ||
         (c >= 0x10800 && c <= 0x10FFF) || (c >= 0x1E800 && c <= 0x1EFFF);
}

NSString *ENRMWordMajorityDirection(NSString *text)
{
  NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
  NSCharacterSet *spaces = [NSCharacterSet whitespaceAndNewlineCharacterSet];
  NSInteger rtl = 0, ltr = 0;
  NSString *first = nil;
  BOOL counted = NO;
  NSUInteger length = text.length;
  for (NSUInteger i = 0; i < length; i++) {
    UTF32Char c = [text characterAtIndex:i];
    if (CFStringIsSurrogateHighCharacter(c) && i + 1 < length) {
      c = CFStringGetLongCharacterForSurrogatePair(c, [text characterAtIndex:++i]);
    }
    if ([spaces longCharacterIsMember:c]) {
      counted = NO;
    } else if (!counted && [letters longCharacterIsMember:c]) {
      BOOL isRTL = ENRMIsRTLLetter(c);
      if (!first)
        first = isRTL ? @"rtl" : @"ltr";
      isRTL ? rtl++ : ltr++;
      counted = YES;
    }
  }
  return rtl == ltr ? first : (rtl > ltr ? @"rtl" : @"ltr");
}

static void ENRMCollectProse(MarkdownASTNode *node, NSMutableString *text, StyleConfig *config)
{
  switch (node.type) {
    case MarkdownNodeTypeCode:
    case MarkdownNodeTypeCodeBlock:
    case MarkdownNodeTypeTable:
    case MarkdownNodeTypeImage:
    case MarkdownNodeTypeVideo:
    case MarkdownNodeTypeLatexMathInline:
    case MarkdownNodeTypeLatexMathDisplay:
      [text appendString:@" "];
      return;
    case MarkdownNodeTypeLink:
      // ponytail: a pill link never votes, even when LinkRenderer falls back to plain text for it.
      if ([config effectiveLinkVariantForURL:node.attributes[@"url"] ?: @""].pill) {
        [text appendString:@" "];
        return;
      }
      break;
    case MarkdownNodeTypeText:
      [text appendString:node.content ?: @""];
      return;
    default:
      break;
  }
  // Separate blocks and line breaks so words on either side don't merge.
  [text appendString:@" "];
  for (MarkdownASTNode *child in node.children)
    ENRMCollectProse(child, text, config);
}

// Returns an annotated copy: the parser shares converted trees between views and
// threads (MarkdownParserBridge), so they must not be mutated.
static MarkdownASTNode *ENRMAnnotatedCopy(MarkdownASTNode *node, NSString *inherited, StyleConfig *config)
{
  MarkdownASTNode *copy = [[MarkdownASTNode alloc] initWithType:node.type];
  copy.content = node.content;
  [copy.attributes addEntriesFromDictionary:node.attributes];

  NSString *direction = nil;
  switch (node.type) {
    case MarkdownNodeTypeDocument:
    case MarkdownNodeTypeTable:
    case MarkdownNodeTypeTableHead:
    case MarkdownNodeTypeTableBody:
    case MarkdownNodeTypeTableRow:
      // Column order stays LTR; each cell resolves on its own.
      break;
    default:
      direction = inherited;
      if (!direction) {
        NSMutableString *text = [NSMutableString string];
        ENRMCollectProse(node, text, config);
        direction = ENRMWordMajorityDirection(text) ?: @"ltr";
      }
      if (ENRMIsTopLevelBlockType(node.type) || node.type == MarkdownNodeTypeListItem ||
          node.type == MarkdownNodeTypeCode || node.type == MarkdownNodeTypeTableCell ||
          node.type == MarkdownNodeTypeTableHeaderCell) {
        copy.attributes[ENRMProseDirectionKey] = direction;
      }
  }
  for (MarkdownASTNode *child in node.children)
    [copy addChild:ENRMAnnotatedCopy(child, direction, config)];
  return copy;
}

MarkdownASTNode *ENRMWordMajorityAST(MarkdownASTNode *root, StyleConfig *config)
{
  return ENRMAnnotatedCopy(root, nil, config);
}
